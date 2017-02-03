/**
* A Lambda function that looks up the latest AMI ID for a given region and architecture.
**/

// Require modules
var aws = require("aws-sdk");
var https = require("https");
var url = require("url");

// Map instance architectures to an AMI name pattern
var archToAMINamePattern = {
    "PV64": "amzn-ami-pv*x86_64-ebs",
    "HVM64": "amzn-ami-hvm*x86_64-gp2",
    "HVMG2": "amzn-ami-graphics-hvm*x86_64-ebs*"
};
 
exports.handler = function(event, context) {
 
    console.log("REQUEST RECEIVED:\n" + JSON.stringify(event));
        
    // Create the default response body
    var parsedUrl = url.parse(event.ResponseURL);
    var responseBody = JSON.stringify({
        Status: "",
        Reason: "See the details in CloudWatch Log Stream: " + context.logStreamName,
        PhysicalResourceId: context.logStreamName,
        StackId: event.StackId,
        RequestId: event.RequestId,
        LogicalResourceId: event.LogicalResourceId,
        Data: {}
    });
    
    // For Delete requests, immediately send a SUCCESS response.
    if (event.RequestType == "Delete") {
        responseBody.Status = "SUCCESS";
        sendResponse(event, context, responseBody);
        context.done();
        return;
    } 
 
    // Get AMI IDs with the specified name pattern and owner
    var props = event.ResourceProperties;
    var archName = archToAMINamePattern[props.Architecture];
    var owner = (props.Architecture === "HVMG2") ? "679593333241" : "amazon";
    var ec2 = new aws.EC2({region: event.ResourceProperties.Region});
    ec2.describeImages({
        Filters: [ { Name: "name", Values: [ archName ] } ],
        Owners: [ owner ]
    })
    
    // If any errors occurred then log them and respond with a FAILED status
    .on("error", function(error) {
        responseBody.Status = "FAILED";
        responseBody.Data = { Error: "DescribeImages call failed" };
        console.log(responseData.Error + ":\n", err);
        sendResponse(parsedUrl, responseBody);
        context.done();
    })
    
    // Otherwise, get the latest stable AMI of those returned
    // Respond with a SUCCESS/FAILED status according to whether one was found
    .on("success", function(describeImagesResult) {
        var latest = latestImage(describeImagesResult.Images);
        responseBody.Status = (latest === null) ? "FAILED" : "SUCCESS";
        if (latest !== null)
            responseBody.Data = { Id: latest.ImageId };
        sendResponse(parsedUrl, responseBody);
        context.done();        
    });
};

// Send response to the pre-signed S3 URL 
function sendResponse(url, responseBody) {
    // Log the response body
    console.log("RESPONSE BODY:\n", responseBody);
 
    // Define an HTTPS request object for the response
    console.log("SENDING RESPONSE...\n");
    https.request({
        hostname: url.hostname,
        port: 443,
        path: url.path,
        method: "PUT",
        headers: {
            "content-type": "",
            "content-length": responseBody.length
        }
    })
    
    // If any errors occur then log them and early exit
    .on("error", function(error) {
        console.log("sendResponse Error:" + error);
    })
    
    // Otherwise, log the response's status and headers
    .on("success", function(response) {
        console.log("STATUS: " + response.statusCode);
        console.log("HEADERS: " + JSON.stringify(response.headers));
    })
  
    // Write the response body to the object
    .write(responseBody)
    .end();
}

function latestImage(images) {
    var latest = null;
    
    // Try to find the latest stable AMI image in the provided list
    // Image names are formatted as YYYY.MM.Ver.
    images.sort(function(x, y) { return y.Name.localeCompare(x.Name); });
    for (var j=0; j < images.length; j++) {
        var lower = images[j].Name.toLowerCase();
        var beta = (lower.indexOf("beta") > -1);
        var rc = (lower.indexOf(".rc") > -1);
        if (!beta && !rc)
            latest = images[j];
    }
    
    return latest;
}