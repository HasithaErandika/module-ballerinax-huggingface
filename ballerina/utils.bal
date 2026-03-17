// Copyright (c) 2026, Hasitha Erandika (http://github.com/HasithaErandika).
// Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: Apache-2.0

import ballerina/log;
import ballerina/url;
import ballerina/regex;

# Encodes a value for safe inclusion in a URI path, preserving `/` separators.
#
# + value - Value to be encoded (typically a model ID)
# + return - The percent-encoded URI string
isolated function getEncodedUri(anydata value) returns string {
    string raw = value.toString();
    string[] segments = regex:split(raw, "/");
    string[] encodedSegments = [];
    foreach string seg in segments {
        string|error encoded = url:encode(seg, "UTF-8");
        if encoded is string {
            encodedSegments.push(encoded);
        } else {
            log:printWarn(string `URI encoding failed for segment "${seg}", using raw value.`,
                'error = encoded);
            encodedSegments.push(seg);
        }
    }
    return string:'join("/", ...encodedSegments);
}