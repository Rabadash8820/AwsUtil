/**
* A Lambda function that looks up the latest AMI ID for a given region and architecture.
**/

// Require modules
var aws = require("aws-sdk");
var https = require("https");
var url = require("url");

// Some global vars
var context;
var returnUrl;
var responseBody;

// Maps from instance types to architectures for various types of AMIs
var instanceTypeToArch = {
    "c1.medium":   "PV64",
    "c1.xlarge":   "PV64",
    "c3.2xlarge":  "HVM64",
    "c3.4xlarge":  "HVM64",
    "c3.8xlarge":  "HVM64",
    "c3.large":    "HVM64",
    "c3.xlarge":   "HVM64",
    "c4.2xlarge":  "HVM64",
    "c4.4xlarge":  "HVM64",
    "c4.8xlarge":  "HVM64",
    "c4.large":    "HVM64",
    "c4.xlarge":   "HVM64",
    "cc2.8xlarge": "HVM64",
    "cr1.8xlarge": "HVM64",
    "d2.2xlarge":  "HVM64",
    "d2.4xlarge":  "HVM64",
    "d2.8xlarge":  "HVM64",
    "d2.xlarge":   "HVM64",
    "g2.2xlarge":  "HVMG2",
    "hi1.4xlarge": "HVM64",
    "hs1.8xlarge": "HVM64",
    "i2.2xlarge":  "HVM64",
    "i2.4xlarge":  "HVM64",
    "i2.8xlarge":  "HVM64",
    "i2.xlarge":   "HVM64",
    "m1.large":    "PV64",
    "m1.medium":   "PV64",
    "m1.small":    "PV64",
    "m1.xlarge":   "PV64",
    "m2.2xlarge":  "PV64",
    "m2.4xlarge":  "PV64",
    "m2.xlarge":   "PV64",
    "m3.2xlarge":  "HVM64",
    "m3.large":    "HVM64",
    "m3.medium":   "HVM64",
    "m3.xlarge":   "HVM64",
    "r3.2xlarge":  "HVM64",
    "r3.4xlarge":  "HVM64",
    "r3.8xlarge":  "HVM64",
    "r3.large":    "HVM64",
    "r3.xlarge":   "HVM64",
    "t1.micro":    "PV64",
    "t2.nano":     "HVM64",
    "t2.medium":   "HVM64",
    "t2.micro":    "HVM64",
    "t2.small":    "HVM64"
};
var archToAMINamePattern = {
    "amzn-linux": {
        "PV64":  "amzn-ami-pv*x86_64-ebs",
        "HVM64": "amzn-ami-hvm*x86_64-gp2",
        "HVMG2": "amzn-ami-graphics-hvm*x86_64-ebs*"
    },
    "hardened-amzn-linux": {
        "PV64":  "CIS Amazon Linux*",
        "HVM64": "CIS Amazon Linux*",
        "HVMG2": "CIS Amazon Linux*"
    }
};

exports.handler = function(event, lambdaContext) { 

    // Log the received request
    console.log("REQUEST RECEIVED:\n" + JSON.stringify(event));
    context = lambdaContext;

    // Create the default response body
    returnUrl = url.parse(event.ResponseURL);
    responseBody = {
        Status: "",
        Reason: "See the details in CloudWatch Log Stream: " + context.logStreamName,
        PhysicalResourceId: context.logStreamName,
        StackId: event.StackId,
        RequestId: event.RequestId,
        LogicalResourceId: event.LogicalResourceId,
        Data: {}
    };

    // For Delete requests, immediately send a SUCCESS response.
    if (event.RequestType === "Delete") {
        responseBody.Status = "SUCCESS";
        sendResponse();
        return;
    }

    // Get AMI IDs with the specified name pattern and owner
    var props = event.ResourceProperties;
    var searchOptions = getInstanceParams(props);
    var ec2 = new aws.EC2({region: props.Region});
    ec2.describeImages(searchOptions)

       // If any errors occurred then log them and respond with a FAILED status
       .on("error", function(error, response) {
            responseBody.Status = "FAILED";
            responseBody.Data = { Error: "DescribeImages call failed" };
            console.log(responseData.Error + ":\n", error);
            sendResponse();
       })

        // Otherwise, get the latest stable AMI of those returned
        // Respond with a SUCCESS/FAILED status according to whether one was found
       .send(function(err, response) {
            var latest = latestImage(response.Images);
            if (latest === null) {
                responseBody.Status = "FAILED";
            }
            else {
                responseBody.Status = "SUCCESS";
                responseBody.Data = { ImageId: latest.ImageId };
            }
            sendResponse();
       });
};

// Send response to the pre-signed S3 URL 
function sendResponse() {
    // Log the response body
    var responseStr = JSON.stringify(responseBody);
    console.log("RESPONSE BODY:\n", responseStr);

    // Define options for the HTTPS response
    var options = {
        hostname: returnUrl.hostname,
        port: 443,
        path: returnUrl.path,
        method: "PUT",
        headers: {
            // "content-type": "",
            "content-length": responseStr.length
        }
    };

    // Define the HTTPS requrest object for the response with these options
    // If successful then log the response's status and headers
    var response = https.request(options, function(response) {
        console.log("STATUS: " + response.statusCode);
        console.log("HEADERS: " + JSON.stringify(response.headers));
        context.done();
    });

    // If any errors occur then log them
    response.on("error", function(error) {
        console.log("sendResponse Error:" + error);
        context.done();
    });

    // Write the response body to the object
    console.log("SENDING RESPONSE...\n");
    response.write(responseStr);
    response.end();
}

function getInstanceParams(properties) {
    // Return the filter options to pass to ec2.describeImages() based on the given parameters
    var lookupType = properties.AmiLookupType;
    var arch = instanceTypeToArch[properties.InstanceType];
    console.log("IMAGE ARCHITECTURE:\t" + arch);
    var nameFilter = archToAMINamePattern[lookupType][arch];
    var options = {
        Filters: [
            { Name:"name",         Values: [ nameFilter ] },
            { Name:"state",        Values: [ "available" ] },
            { Name:"image-type",   Values: [ "machine" ] },
            { Name:"architecture", Values: [ "x86_64" ] }
        ],
        // Owners: [ ]
    };

    console.log("IMAGE SEARCH OPTIONS:\n" + JSON.stringify(options));
    return options;
}

function latestImage(images) {
    var latest = null;

    // Sort images in descending order based on CreationDate
    images.sort(function(x, y) {
        var xd = new Date(x.CreationDate);
        var yd = new Date(y.CreationDate);
        return yd.getTime() - xd.getTime();
    });

    // Return the latest stable AMI
    console.log("SORTED AMIs:\n" + JSON.stringify(images));
    for (var j=0; j < images.length; j++) {
        var lower = images[j].Name.toLowerCase();
        var beta = (lower.indexOf("beta") > -1);
        var rc = (lower.indexOf(".rc") > -1);
        if (!beta && !rc) {
            latest = images[j];
            break;
        }
    }

    return latest;
}