#!/bin/bash
usage(){
    echo "Usage: [-r | --reportDir ReportPath] [-c | --config configFile] [-s | --service service_name]"
}

FOLDER_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

REPORT_MOCHAWESOME_SERVICE_PATH=
TEST_CONFIG_FILEPATH=
SERVICE_NAME=

while getopts "r:c:s:-:" options; do
    case ${options} in
        -)
            case "${OPTARG}" in
                reportDir)
                    REPORT_MOCHAWESOME_SERVICE_PATH=${!OPTIND}; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                config)
                    TEST_CONFIG_FILEPATH=${!OPTIND}; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                service)
                    SERVICE_NAME=${!OPTIND}; OPTIND=$(( $OPTIND + 1 ))
            esac;;
        r)
            REPORT_MOCHAWESOME_SERVICE_PATH=${OPTARG}
            ;;
        c)
            TEST_CONFIG_FILEPATH=${OPTARG}
            ;;
        s)
            SERVICE_NAME=${OPTARG}
            ;;
        :)
            echo "option -${OPTARG} requires an argument"
            usage
            exit 1
            ;;
        *)
            echo ${options}
            usage
            exit 1
            ;;

    esac
done

if [ -z "$REPORT_MOCHAWESOME_SERVICE_PATH" ] || [ -z "$TEST_CONFIG_FILEPATH" ]
then
    echo "-r, -c and -s arguments needed"
    usage
    exit 1
fi


report_path_arr=(${REPORT_MOCHAWESOME_SERVICE_PATH//\// })
automation_folder=${report_path_arr[0]}


if [ ! -f $REPORT_MOCHAWESOME_SERVICE_PATH/mochawesome.json ]
then
    echo "Error: There is no report file in $REPORT_MOCHAWESOME_SERVICE_PATH"
    exit 1
fi

MERGED=false
# echo "Merging mochawesome jsons"
mkdir -p $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged
node $automation_folder/node_modules/.bin/mochawesome-merge  --reportDir $REPORT_MOCHAWESOME_SERVICE_PATH > $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged/mochawesome-merge.json
if [ $? -eq 0 ]
then
    MERGED=true
else
    echo "failed to merge"
    exit 1
fi

#GENERATE HTML REPORT
# if [ $MERGED = true ]
# then
#     echo "Generating html report"
#     if [ ! -f "$REPORT_MOCHAWESOME_SERVICE_PATH/merge/mochawesome-merge.json" ]
#     then
#         echo "Error: mochawesome-merge.json not found"
#         exit 1
#     fi
#     npx mochawesome-report-generator $REPORT_MOCHAWESOME_SERVICE_PATH/merge/mochawesome-merge.json -o $REPORT_MOCHAWESOME_SERVICE_PATH/html/
# fi


# echo "Extracting test results information"

test_name=$(jq -r '.env.test_name' $TEST_CONFIG_FILEPATH.json)
test_env=$(jq -r '.env.env_name' $TEST_CONFIG_FILEPATH.json)
num_tests=$(jq -r '.stats.tests' $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged/mochawesome-merge.json)
num_suites=$(jq -r '.stats.suites' $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged/mochawesome-merge.json)
failures=$(jq -r '.stats.failures' $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged/mochawesome-merge.json)
payload=

service_lower=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]')

if [ -n "$test_name" ]
then
    payload='
    {
        "text":"*Cypress '${ENV_NAME^}' Automation Report*\n\n*Service Name: '$SERVICE_NAME'*\n*Test Name: '$test_name'*\n*Number of test suite(s): '$num_suites'*\t*Number of test(s): '$num_tests'*\n*Failures: '$failures'*\n",
        "attachments": [
            {
                "color": "#458b00",
                "fallback": "Jenkins url: '${BUILD_URL}'",
                "actions":[
                    {
                        "type": "button",
                        "text": "Jenkins",
                        "url": "'${BUILD_URL}'",
                        "style":"primary"
                    },{
                        "type": "button",
                        "text": "HTML Report",
                        "url": "",
                        "style":"primary"
                    }
                ]
            }
        ]
    }
    '
else
    payload='
    {
        "text":"*Cypress '${ENV_NAME^}' Automation Report*\n\n*Service Name: '$SERVICE_NAME'*\n*Number of test suite(s): '$num_suites'*\t*Number of test(s): '$num_tests'*\n*Failures: '$failures'*\n",
        "attachments": [
            {
                "color": "#458b00",
                "fallback": "Jenkins url: '${BUILD_URL}'",
                "actions":[
                    {
                        "type": "button",
                        "text": "Jenkins",
                        "url": "'${BUILD_URL}'",
                        "style":"primary"
                    },{
                        "type": "button",
                        "text": "HTML Report",
                        "url": "",
                        "style":"primary"
                    }
                ]
            }
        ]
    }
    '
fi

indexSuite=0
slack=false
for i in $(jq -r ".suites.suites[] | @base64" $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged/mochawesome-merge.json)
do 
    # echo $i | base64 --decode | jq -r ".title"
    footerElem=
    pass=true

    for j in $(echo $i | base64 --decode | jq -r 'map(.. | select(.fail? == true)) | .[] | @base64')
    do    
        decodedTestCase=$(echo $j | base64 --decode)
        # echo $decodedTestCase | tr '\r\n' ' ' | jq -r ".title"
        if [ $(echo $decodedTestCase | tr '\r\n' ' ' | jq -r ".fail") = true ]
        then
            pass=false
            slack=true
            testCaseTitle=$(echo $decodedTestCase | tr '\r\n' ' ' | jq -r ".title")
            errMsg=$(echo $decodedTestCase | tr '\r\n' ' ' | jq -r ".err.message" | tr '\n' ' ' | cut -c1-55)
            footerElem+='-'$testCaseTitle': '$(echo $errMsg)'\n'
        fi
    done
    if [ -z "$footerElem" ]
    then
        footerElem=""
    fi
    if [ "$pass" = false ]
    then
        suiteTitle=$(echo $i | base64 --decode | jq -r ".title" | sed 's/\"/\\"/g' )
	#suiteTitle=${suiteTitle//\"/\\"}
        attachmentElem='
        {
            "color": "#8b0000",
            "title": "Test Suite '$((indexSuite+1))': \"'$suiteTitle'\"",
            "footer": "'$(echo $footerElem | sed 's/\\'"'"'/'"\""'/g' | sed 's/\"/\\"/g' | sed 's/'"'"'/\\"/g')'"
        }
        '
        payload=$(jq ".attachments += [$attachmentElem]" <<< "$payload")
    fi
    ((indexSuite++))
done

payload=$(jq ". += {\"num_suites\": \"$(echo $num_suites)\"}" <<< "$payload")
payload=$(jq ". += {\"num_tests\": \"$(echo $num_tests)\"}" <<< "$payload")
payload=$(jq ". += {\"failures\": \"$(echo $failures)\"}" <<< "$payload")
payload=$(jq ". += {\"passed\": \"$((num_tests - failures))\"}" <<< "$payload")

#if [ $slack = true ]
#then
    echo $payload
    # curl -i -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_HOOK"
#fi

#https://hooks.slack.com/services/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
#Cleaning report files
# rm $REPORT_MOCHAWESOME_SERVICE_PATH/*.json
# rm $REPORT_MOCHAWESOME_SERVICE_PATH/../merge/*.json
