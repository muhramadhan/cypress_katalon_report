#!/usr/bin/env bash

usage(){
    echo "Usage: [-r | --reportDir ReportPath] [-t | --timestamps \"time1,time2,time3\"]] [-s | --service service_name]"
}


REPORT_DIR=
SERVICE_NAME=
TIMESTAMPS=

# Input param
while getopts "r:t:s:-:" options; do
    case ${options} in
        -)
            case "${OPTARG}" in
                reportDir)
                    REPORT_MOCHAWESOME_SERVICE_PATH=${!OPTIND}; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                service)
                    SERVICE_NAME=${!OPTIND}; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                timestamps)
                    TIMESTAMPS=${!OPTIND}; OPTIND=$(( $OPTIND + 1 ))
                    ;;
            esac;;
        r)
            REPORT_DIR=${OPTARG}
            ;;
        s)
            SERVICE_NAME=${OPTARG}
            ;;
        t)
            TIMESTAMPS=${OPTARG}
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

# payload='
# {
#     "text":"*Katalon Staging Automation Report*\n\n*Service Name: '$SERVICE_NAME'*\n*Test Name: '$TEST_NAME'*\n*Number of test(s): '$num_tests'*\t*Passed: '$passed'*\t*Failures: '$failures'*\t*Errors: '$errors'*\n",
#     "attachments": [
#         {
#             "color": "#458b00",
#             "fallback": "Jenkins url: '$BUILD_URL'",
#             "actions":[
#                 {
#                     "type": "button",
#                     "text": "Jenkins",
#                     "url": "'$BUILD_URL'",
#                     "style":"primary"
#                 },{
#                     "type": "button",
#                     "text": "HTML Report",
#                     "url": "",
#                     "style":"primary"
#                 }
#             ]
#         }
#     ]
# }
# '
payload='
{
    "attachments": [
        {
            "color": "#458b00",
            "fallback": "Jenkins url: '$BUILD_URL'",
            "actions":[
                {
                    "type": "button",
                    "text": "Jenkins",
                    "url": "'$BUILD_URL'",
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

time_arr=(${TIMESTAMPS//,/ })
passed_total=0
failures_total=0
errors_total=0
num_tests_total=0
SLACK=false
maxAttachment=90
currAttachment=0
for curr_timestamp in ${time_arr[@]}
do
    # Extracting test information
    ## index start from 1
    # test_name=$(xmllint --xpath "string(//testsuite[1]/@id)" $REPORT_DIR/JUnit_Report.xml) #asumsi test suite cuma 1
    passed=$(xmllint --xpath "string(//testsuite[1]/@tests)" $REPORT_DIR/${curr_timestamp}/JUnit_Report.xml)
    failures=$(xmllint --xpath "string(//testsuite[1]/@failures)" $REPORT_DIR/${curr_timestamp}/JUnit_Report.xml)
    errors=$(xmllint --xpath "string(//testsuite[1]/@errors)" $REPORT_DIR/${curr_timestamp}/JUnit_Report.xml)
    num_tests=$((passed + failures + errors))

    passed_total=$((passed_total + passed))
    failures_total=$((failures_total + failures))
    errors_total=$((errors_total + errors))
    num_tests_total=$((num_tests_total + num_tests))
    

    ##Loop failed testcase(s)
    INDEX=1
    while [[ ($INDEX -le $failures) && ($currAttachment -lt $maxAttachment) ]];do
            testcaseName=$(xmllint --xpath "string(//testcase[@status='FAILED'][$INDEX]/@name)" $REPORT_DIR/${curr_timestamp}/JUnit_Report.xml)

            attachmentElem='
            {
                "color": "#8b0000",
                "title": "\"'$testcaseName'\""
            }
            '
            payload=$(jq ".attachments += [$attachmentElem]" <<< "$payload")
            SLACK=true
            ((INDEX++))
            ((currAttachment++))
    done

    INDEX=1
    while [[ ($INDEX -le $errors) && ($currAttachment -lt $maxAttachment) ]];do
            testcaseName=$(xmllint --xpath "string(//testcase[@status='ERROR'][$INDEX]/@name)" $REPORT_DIR/${curr_timestamp}/JUnit_Report.xml)

            attachmentElem='
            {
                "color": "#d07e00",
                "title": "\"'$testcaseName'\""
            }
            '
            payload=$(jq ".attachments += [$attachmentElem]" <<< "$payload")
            SLACK=true
            ((INDEX++))
            ((currAttachment++))
    done
done

cutoffText=''
if [[ ((failures_total + errors_total)) -gt $maxAttachment ]]
then
    cutoffText='Note: not all test case are shown, check the file for more detailed report'
fi

headerText='"*Katalon '${ENV_NAME^}' Automation Report*\n\n*Service Name: '$SERVICE_NAME'*\n*Test Name: '$TEST_NAME'*\n*Number of test(s): '$num_tests_total'*\t*Passed: '$passed_total'*\t*Failures: '$failures_total'*\t*Errors: '$errors_total'*\n'$cutoffText'"'

payload=$(jq ". += {\"text\": $(echo $headerText)}" <<< "$payload")

payload=$(jq ". += {\"num_tests\": $(echo $num_tests_total)}" <<< "$payload")
payload=$(jq ". += {\"failures\": $(echo $failures_total)}" <<< "$payload")
payload=$(jq ". += {\"errors\": $(echo $errors_total)}" <<< "$payload")
payload=$(jq ". += {\"passed\": $(echo $passed_total)}" <<< "$payload")

payload=$(jq ". += {\"channel\": \"toe-alert-space\"}" <<< "$payload")

#if [[ $SLACK = true ]]
#then
    echo $payload
    # curl -i -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_HOOK"
#fi
