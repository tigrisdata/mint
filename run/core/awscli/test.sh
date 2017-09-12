#!/bin/bash
#
#  Mint (C) 2017 Minio, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

HASH_1_MB=$(md5sum "${MINT_DATA_DIR}/datafile-1-MB" | awk '{print $1}')

_init() {
    AWS="aws --endpoint-url $1"
}

function get_time() {
    date +%s%N
}

function get_duration() {
    start_time=$1
    end_time=$(get_time)

    echo $(( (end_time - start_time) / 1000000 ))
}

function log_success() {
    printf '{"name": "awscli", "duration": "%d", "function": "%s", "status": "PASS"}\n' "$1" "$2"
}

function log_failure() {
    printf '{"name": "awscli", "duration": "%d", "function": "%s", "status": "FAIL", "error": "%s"}\n' "$1" "$2" "$3"
}

function log_alert() {
    printf '{"name": "awscli", "duration": "%d", "function": "%s", "status": "FAIL", "alert": "%d", error": "%s"}\n' "$1" "$2" "$3" "$4"
}

function create_random_string() {
    random_str=$(tr -dc 'a-z0-9' < /dev/urandom  | fold -w 32 | head -n 1)
    echo "$random_str"
}

function make_bucket() {
    # Make bucket
    bucket_name="awscli-mint-test-bucket-$RANDOM"
    function="${AWS} s3api create-bucket --bucket ${bucket_name}"

    # execute the test
    out=$($function 2>&1)
    rv=$?

    # if command is successful print bucket_name or print error
    if [ $rv -eq 0 ]; then
        echo "${bucket_name}"
    else    
        echo "${out}"
    fi

    return $rv
}

function delete_bucket() {
    # Delete bucket
    function="${AWS} s3 rb s3://${1} --force"
    out=$($function 2>&1)
    rv=$?

    # echo the output
    echo "${out}"

    return $rv
}

# Tests creating, stat and delete on a bucket.
function test_create_bucket() {
    # log start time
    start_time=$(get_time)

    function="make_bucket"
    bucket_name=$(make_bucket)  
    rv=$?

    # if make_bucket is successful stat the bucket
    if [ $rv -eq 0 ]; then
        function="${AWS} s3api head-bucket --bucket ${bucket_name}"
        out=$($function 2>&1) 
        rv=$?
    else 
        # if make bucket failes, $bucket_name has the error output
        out="${bucket_name}"
    fi

     # if stat bucket is successful remove the bucket
    if [ $rv -eq 0 ]; then
        function="delete_bucket"
        out=$(delete_bucket "${bucket_name}") 
        rv=$?
    else 
        # if make bucket failes, $bucket_name has the error output
        out="${bucket_name}"
    fi

    if [ $rv -eq 0 ]; then
        log_success "$(get_duration "$start_time")" "${function}"
    else
        log_failure "$(get_duration "$start_time")" "${function}" "${out}"
    fi

    return $rv
}

# Tests creating and deleting an object.
function test_create_object() {
    # log start time
    start_time=$(get_time)

    function="make_bucket"
    bucket_name=$(make_bucket)  
    rv=$?

    # if make bucket succeeds upload a file
    if [ $rv -eq 0 ]; then
        function="${AWS} s3api put-object --body ${MINT_DATA_DIR}/datafile-1-MB --bucket ${bucket_name} --key datafile-1-MB"
        out=$($function 2>&1)
        rv=$?
    else 
        # if make bucket fails, $bucket_name has the error output
        out="${bucket_name}"
    fi

    # if upload succeeds download the file
    if [ $rv -eq 0 ]; then 
        function="${AWS} s3api get-object --bucket ${bucket_name} --key datafile-1-MB /tmp/datafile-1-MB"
        # save the ref to function being tested, so it can be logged
        test_function=${function}
        out=$($function 2>&1)
        rv=$?        
        # calculate the md5 hash of downloaded file
        hash2=$(md5sum /tmp/datafile-1-MB | awk '{print $1}')
    fi

    # if download succeeds, verify downloaded file
    if [ $rv -eq 0 ]; then 
        if [ "$HASH_1_MB" == "$hash2" ]; then
            function="delete_bucket"
            out=$(delete_bucket "$bucket_name") 
            rv=$?
            # remove download file
            rm -rf /tmp/datafile-1-MB
        else
            rv=1
        fi
    fi

    if [ $rv -eq 0 ]; then
        log_success "$(get_duration "$start_time")" "${test_function}"
    else
        log_failure "$(get_duration "$start_time")" "${function}" "${out}"
    fi

    return $rv
}

# Tests listing objects for both v1 and v2 API.
function test_list_objects() {
    # log start time
    start_time=$(get_time)

    function="make_bucket"
    bucket_name=$(make_bucket)  
    rv=$?

    # if make bucket succeeds upload a file
    if [ $rv -eq 0 ]; then
        function="${AWS} s3api put-object --body ${MINT_DATA_DIR}/datafile-1-MB --bucket ${bucket_name} --key datafile-1-MB"
        out=$($function 2>&1)
        rv=$?
    else 
        # if make bucket fails, $bucket_name has the error output
        out="${bucket_name}"
    fi

    # if upload objects succeeds, list objects with existing prefix
    if [ $rv -eq 0 ]; then 
        function="${AWS} s3api list-objects --bucket ${bucket_name} --prefix datafile-1-MB"
        test_function=${function}
        key_name=$($function | jq -r .Contents[].Key)
        rv=$?
        if [ "$key_name" != "datafile-1-MB" ]; then
            rv=1            
        fi
    fi

    # if upload objects succeeds, list objects without existing prefix
    if [ $rv -eq 0 ]; then 
        function="${AWS} s3api list-objects --bucket ${bucket_name} --prefix linux"
        key_name=$($function | jq -r .Contents[].Key)
        rv=$?
        if [ "$key_name" != "" ]; then
            rv=1            
        fi
    fi

    # if upload objects succeeds, list objectsv2 with existing prefix
    if [ $rv -eq 0 ]; then 
        function="${AWS} s3api list-objects-v2 --bucket ${bucket_name} --prefix datafile-1-MB"
        key_name=$($function | jq -r .Contents[].Key)
        rv=$?
        if [ "$key_name" != "datafile-1-MB" ]; then
            rv=1 
        fi
    fi

    # if upload objects succeeds, list objectsv2 without existing prefix
    if [ $rv -eq 0 ]; then 
        function="${AWS} s3api list-objects-v2 --bucket ${bucket_name} --prefix linux"
        key_name=$($function | jq -r .Contents[].Key)
        rv=$?
        if [ "$key_name" != "" ]; then
            rv=1
        fi
    fi
    
    if [ $rv -eq 0 ]; then 
        function="delete_bucket"
        out=$(delete_bucket "$bucket_name") 
        rv=$?
        # remove download file
        rm -rf /tmp/datafile-1-MB
    fi

    if [ $rv -eq 0 ]; then
        log_success "$(get_duration "$start_time")" "${test_function}"
    else
        log_failure "$(get_duration "$start_time")" "${function}" "${out}"
    fi

    return $rv
}

# Tests multipart API by making each individual calls.
function test_multipart_upload() {
    # log start time
    start_time=$(get_time)

    function="make_bucket"
    bucket_name=$(make_bucket)  
    object_name=${bucket_name}"-object"
    rv=$?

    # if make bucket succeeds upload a file
    if [ $rv -eq 0 ]; then
        function="${AWS} s3api put-object --body ${MINT_DATA_DIR}/datafile-1-MB --bucket ${bucket_name} --key datafile-1-MB"
        out=$($function 2>&1)
        rv=$?
    else 
        # if make bucket fails, $bucket_name has the error output
        out="${bucket_name}"
    fi

    if [ $rv -eq 0 ]; then
        # create multipart
        function="${AWS} s3api create-multipart-upload --bucket ${bucket_name} --key ${object_name}"
        test_function=${function}
        upload_id=$($function | jq -r .UploadId)
        rv=$?
    fi

    if [ $rv -eq 0 ]; then
        # Capture etag for part-number 1
        function="${AWS} s3api upload-part --bucket ${bucket_name} --key ${object_name} --body ${MINT_DATA_DIR}/datafile-5-MB --upload-id ${upload_id} --part-number 1"
        etag1=$($function | jq -r .ETag)
        rv=$?
    fi

    if [ $rv -eq 0 ]; then
        # Capture etag for part-number 2
        function="${AWS} s3api upload-part --bucket ${bucket_name} --key ${object_name} --body ${MINT_DATA_DIR}/datafile-1-MB --upload-id ${upload_id} --part-number 2"
        etag2=$($function | jq -r .ETag)
        rv=$?
        # Create a multipart struct file for completing multipart transaction
        echo "{
            \"Parts\": [
                {
                    \"ETag\": ${etag1},
                    \"PartNumber\": 1
                },
                {
                    \"ETag\": ${etag2},
                    \"PartNumber\": 2
                }
            ]
        }" >> /tmp/multipart
    fi

    if [ $rv -eq 0 ]; then
        # Use saved etags to complete the multipart transaction
        function="${AWS} s3api complete-multipart-upload --multipart-upload file:///tmp/multipart --bucket ${bucket_name} --key ${object_name} --upload-id ${upload_id}"
        finalETag=$($function  | jq -r .ETag)
        rv=$?
        if [ "${finalETag}" == "" ]; then
            rv=1
        fi
    fi

    if [ $rv -eq 0 ]; then
        log_success "$(get_duration "$start_time")" "${test_function}"
    else
        log_failure "$(get_duration "$start_time")" "${function}" "${out}"
    fi

    return $rv
}

# Copy object tests for server side copy
# of the object, validates returned md5sum.
function test_copy_object() {
    # log start time
    start_time=$(get_time)

    function="make_bucket"
    bucket_name=$(make_bucket)  
    rv=$?

    # if make bucket succeeds upload a file
    if [ $rv -eq 0 ]; then
        function="${AWS} s3api put-object --body ${MINT_DATA_DIR}/datafile-1-MB --bucket ${bucket_name} --key datafile-1-MB"
        out=$($function 2>&1)
        rv=$?
    else 
        # if make bucket fails, $bucket_name has the error output
        out="${bucket_name}"
    fi

    # copy object server side
    if [ $rv -eq 0 ]; then 
        function="${AWS} s3api copy-object --bucket ${bucket_name} --key datafile-1-MB-copy --copy-source ${bucket_name}/datafile-1-MB"
        test_function=${function}
        out=$($function)
        rv=$?
        hash2=$(echo "$out" | jq -r .CopyObjectResult.ETag | sed -e 's/^"//' -e 's/"$//')
        if [ "$HASH_1_MB" == "$hash2" ]; then
            function="delete_bucket"
            out=$(delete_bucket "$bucket_name") 
            rv=$?
        else
            rv=1
        fi
    fi

    if [ $rv -eq 0 ]; then
        log_success "$(get_duration "$start_time")" "${test_function}"
    else
        log_failure "$(get_duration "$start_time")" "${function}" "${out}"
    fi

    return $rv
}

# Tests for presigned URL success case, presigned URL
# is correct and accessible - we calculate md5sum of
# the object and validate it against a local files md5sum.
function test_presigned_object() {
    # log start time
    start_time=$(get_time)

    function="make_bucket"
    bucket_name=$(make_bucket)  
    rv=$?

    # if make bucket succeeds upload a file
    if [ $rv -eq 0 ]; then
        function="${AWS} s3api put-object --body ${MINT_DATA_DIR}/datafile-1-MB --bucket ${bucket_name} --key datafile-1-MB"
        out=$($function 2>&1)
        rv=$?
    else 
        # if make bucket fails, $bucket_name has the error output
        out="${bucket_name}"
    fi

    if [ $rv -eq 0 ]; then
        function="${AWS} s3 presign s3://${bucket_name}/datafile-1-MB"
        test_function=${function}
        url=$($function)
        rv=$?
        hash2=$(curl -sS "${url}" | md5sum -)
        hash2=${hash2:0:32}
        if [ "$HASH_1_MB" == "$hash2" ]; then
            function="delete_bucket"
            out=$(delete_bucket "$bucket_name") 
            rv=$?
        else
            rv=1
        fi
    fi

    if [ $rv -eq 0 ]; then
        log_success "$(get_duration "$start_time")" "${test_function}"
    else
        log_failure "$(get_duration "$start_time")" "${function}" "${out}"
    fi

    return $rv
}

# Tests `aws s3 cp` by uploading a local file.
function test_aws_s3_cp() {
    file_name="${MINT_DATA_DIR}/datafile-65-MB"

    # log start time
    start_time=$(get_time)

    function="make_bucket"
    bucket_name=$(make_bucket) 
    rv=$?

    # if make bucket succeeds upload a file using cp
    if [ $rv -eq 0 ]; then
        function="${AWS} s3 cp $file_name s3://${bucket_name}/$(basename "$file_name")"
        test_function=${function}
        out=$($function 2>&1)
        rv=$?
    else 
        # if make bucket fails, $bucket_name has the error output
        out="${bucket_name}"
    fi

    if [ $rv -eq 0 ]; then
        function="${AWS} s3 rm s3://${bucket_name}/$(basename "$file_name")"
        out=$($function 2>&1)
        rv=$?
    fi

    if [ $rv -eq 0 ]; then
        function="${AWS} s3 rb s3://${bucket_name}/"
        out=$($function 2>&1)
        rv=$?
    fi
    
    if [ $rv -eq 0 ]; then
        log_success "$(get_duration "$start_time")" "${test_function}"
    else
        log_failure "$(get_duration "$start_time")" "${function}" "${out}"
    fi

    return $rv
}

# Tests `aws s3 sync` by mirroring all the
# local content to remove bucket.
function test_aws_s3_sync() {
    # log start time
    start_time=$(get_time)

    function="make_bucket"
    bucket_name=$(make_bucket) 
    rv=$?

    # if make bucket succeeds sync all the files in a directory
    if [ $rv -eq 0 ]; then
        function="${AWS} s3 sync $MINT_DATA_DIR s3://${bucket_name}/"
        test_function=${function}
        out=$($function 2>&1)
        rv=$?
    else 
        # if make bucket fails, $bucket_name has the error output
        out="${bucket_name}"
    fi

    # remove files recusively
    if [ $rv -eq 0 ]; then
        function="${AWS} s3 rm --recursive s3://${bucket_name}/"
        out=$($function 2>&1)
        rv=$?
    fi

    # delete bucket
    if [ $rv -eq 0 ]; then
        function="delete_bucket"
        out=$(delete_bucket "$bucket_name") 
        rv=$?
    fi 

    if [ $rv -eq 0 ]; then
        log_success "$(get_duration "$start_time")" "${test_function}"
    else
        log_failure "$(get_duration "$start_time")" "${function}" "${out}"
    fi

    return $rv
}

# list objects negative test - tests for following conditions.
# v1 API with max-keys=-1 and max-keys=0
# v2 API with max-keys=-1 and max-keys=0
function test_list_objects_error() {
    # log start time
    start_time=$(get_time)

    function="make_bucket"
    bucket_name=$(make_bucket)  
    rv=$?

    # if make bucket succeeds upload a file
    if [ $rv -eq 0 ]; then
        function="${AWS} s3api put-object --body ${MINT_DATA_DIR}/datafile-1-MB --bucket ${bucket_name} --key datafile-1-MB"
        out=$($function 2>&1)
        rv=$?
    else 
        # if make bucket fails, $bucket_name has the error output
        out="${bucket_name}"
    fi

    if [ $rv -eq 0 ]; then
        # Server replies an error for v1 with max-key=-1
        function="${AWS} s3api list-objects --bucket ${bucket_name} --prefix datafile-1-MB --max-keys=-1"
        test_function=${function}
        out=$($function 2>&1)
        rv=$?
        if [ $rv -ne 255 ]; then
            rv=1
        else 
            rv=0
        fi
    fi

    if [ $rv -eq 0 ]; then
        # Server replies an error for v2 with max-keys=-1
        function="${AWS} s3api list-objects-v2 --bucket ${bucket_name} --prefix datafile-1-MB --max-keys=-1"
        test_function=${function}
        out=$($function 2>&1)
        rv=$?
        if [ $rv -ne 255 ]; then
            rv=1
        else 
            rv=0
        fi
    fi

    if [ $rv -eq 0 ]; then
        # Server returns success with no keys when max-keys=0
        function="${AWS} s3api list-objects-v2 --bucket ${bucket_name} --prefix datafile-1-MB --max-keys=0"
        out=$($function 2>&1)
        rv=$?
        if [ $rv -eq 0 ]; then
            function="delete_bucket"
            out=$(delete_bucket "$bucket_name") 
            rv=$?
        fi
    fi

    if [ $rv -eq 0 ]; then
        log_success "$(get_duration "$start_time")" "${test_function}"
    else
        log_failure "$(get_duration "$start_time")" "${function}" "${out}"
    fi

    return $rv
}

# put object negative test - tests for following conditions.
# - invalid object name.
# - invalid Content-Md5
# - invalid Content-Length
function test_put_object_error() {
    # log start time
    start_time=$(get_time)

    function="make_bucket"
    bucket_name=$(make_bucket)  
    rv=$?

    # if make bucket succeeds upload a file with invalid object_name
    if [ $rv -eq 0 ]; then
        function="${AWS} s3api put-object --body ${MINT_DATA_DIR}/datafile-1-MB --bucket ${bucket_name} --key /2123123\123"
        out=$($function 2>&1)
        rv=$?
        if [ $rv -ne 255 ]; then
            rv=1
        else 
            rv=0
        fi
    else 
        # if make bucket fails, $bucket_name has the error output
        out="${bucket_name}"
    fi

    # upload an object without content-md5.
    if [ $rv -eq 0 ]; then
        function="${AWS} s3api put-object --body ${MINT_DATA_DIR}/datafile-1-MB --bucket ${bucket_name} --key datafile-1-MB --content-md5 invalid"
        test_function=${function}
        out=$($function 2>&1)
        rv=$?
        if [ $rv -ne 255 ]; then
            rv=1
        else 
            rv=0
        fi
    fi

    # upload an object without content-length.
    if [ $rv -eq 0 ]; then
        function="${AWS} s3api put-object --body ${MINT_DATA_DIR}/datafile-1-MB --bucket ${bucket_name} --key datafile-1-MB --content-length -1"
        test_function=${function}
        out=$($function 2>&1)
        rv=$?
        if [ $rv -ne 255 ]; then
            rv=1
        else 
            rv=0
        fi
    fi

    if [ $rv -eq 0 ]; then
        function="delete_bucket"
        out=$(delete_bucket "$bucket_name") 
        rv=$?
    fi

    if [ $rv -eq 0 ]; then
        log_success "$(get_duration "$start_time")" "${test_function}"
    else
        log_failure "$(get_duration "$start_time")" "${function}" "${out}"
    fi

    return $rv
}

# main handler for all the tests.
main() {
    # Success tests
    test_create_bucket
    test_create_object
    test_list_objects
    test_multipart_upload
    test_copy_object
    test_presigned_object

    # Success cli ops.
    test_aws_s3_cp
    test_aws_s3_sync

    # Error tests
    test_list_objects_error
    test_put_object_error
}

_init "$@" && main
