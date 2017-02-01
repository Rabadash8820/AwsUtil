/**
* A sample Lambda function that looks up the latest AMI ID for a given region and architecture.
**/

// Map instance architectures to an AMI name pattern
var archToAMINamePattern = {
    "PV64": "amzn-ami-pv*x86_64-ebs",
    "HVM64": "amzn-ami-hvm*x86_64-gp2",
    "HVMG2": "amzn-ami-graphics-hvm*x86_64-ebs*"
};
var aws = require("aws-sdk");
 
exports.handler = function(event, context) {
 
    console.log("REQUEST RECEIVED:\n" + JSON.stringify(event));
    
    // For Delete requests, immediately send a SUCCESS response.
    if (event.RequestType == "Delete") {
        sendResponse(event, context, "SUCCESS");
        return;
    }
 
    var responseStatus = "FAILED";
    var responseData = {};
 
    var ec2 = new aws.EC2({region: event.ResourceProperties.Region});
    var describeImagesParams = {
        Filters: [{ Name: "name", Values: [archToAMINamePattern[event.ResourceProperties.Architecture]]}],
        Owners: [event.ResourceProperties.Architecture == "HVMG2" ? "679593333241" : "amazon"]
    };
 
    // Get AMI IDs with the specified name pattern and owner
    ec2.describeImages(describeImagesParams, function(err, describeImagesResult) {
        if (err) {
            responseData = {Error: "DescribeImages call failed"};
            console.log(responseData.Error + ":\n", err);
        }
        else {
            var images = describeImagesResult.Images;
            // Sort images by name in decscending order. The names contain the AMI version, formatted as YYYY.MM.Ver.
            images.sort(function(x, y) { return y.Name.localeCompare(x.Name); });
            for (var j = 0; j < images.length; j++) {
                if (isBeta(images[j].Name)) continue;
                responseStatus = "SUCCESS";
                responseData["Id"] = images[j].ImageId;
                break;
            }
        }
        sendResponse(event, context, responseStatus, responseData);
    });
};

// Check if the image is a beta or rc image. The Lambda function won't return any of those images.
function isBeta(imageName) {
    var containsBeta = (imageName.toLowerCase().indexOf("beta") > -1);
    var containsRC = (imageName.toLowerCase().indexOf(".rc") > -1);
    return containsBeta || containsRC;
}


// Send response to the pre-signed S3 URL 
function sendResponse(event, context, responseStatus, responseData) {
  
    // Create the response body and log it
    var responseBody = JSON.stringify({
        Status: responseStatus,
        Reason: "See the details in CloudWatch Log Stream: " + context.logStreamName,
        PhysicalResourceId: context.logStreamName,
        StackId: event.StackId,
        RequestId: event.RequestId,
        LogicalResourceId: event.LogicalResourceId,
        Data: responseData
    });
    console.log("RESPONSE BODY:\n", responseBody);
        
    // Create the response options
    var parsedUrl = url.parse(event.ResponseURL);
    var options = {
        hostname: parsedUrl.hostname,
        port: 443,
        path: parsedUrl.path,
        method: "PUT",
        headers: {
            "content-type": "",
            "content-length": responseBody.length
        }
    };
    
    // Success and error callbacks for the response
    var successCallback = function(response) {
        console.log("STATUS: " + response.statusCode);
        console.log("HEADERS: " + JSON.stringify(response.headers));
        context.done();   // Tell AWS Lambda that the function execution is done
    };
    var errCallback = function(error) {
        console.log("sendResponse Error:" + error);
        context.done();   // Tell AWS Lambda that the function execution is done
    }
 
    // Define an HTTPS request object with the above options and callbacks
    var request = https.request(options);
    request.on("success", successCallback);
    request.on("error", errCallback);
  
    // Write the response body to the object
    console.log("SENDING RESPONSE...\n");
    request.write(responseBody);
    request.end();
}