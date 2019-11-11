#!/usr/bin/env bash

usage(){
    echo "Usage: [-r | --reportDir ReportPath] [-s | --service service_name]"
}


## param = $(echo "$asd" | grep -E -o -m 1 '\d{8}_\d{6}')/JUnit_Report.xml
REPORT_DIR=
SERVICE_NAME=

# Input param
while getopts "r:s:-:" options; do
    case ${options} in
        -)
            case "${OPTARG}" in
                reportDir)
                    REPORT_MOCHAWESOME_SERVICE_PATH=${!OPTIND}; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                service)
                    SERVICE_NAME=${!OPTIND}; OPTIND=$(( $OPTIND + 1 ))
            esac;;
        r)
            REPORT_DIR=${OPTARG}
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


# Extracting test information
## index start from 1
test_name=$(xmllint --xpath "string(//testsuite[1]/@id)" $REPORT_DIR/JUnit_Report.xml) #asumsi test suite cuma 1
passed=$(xmllint --xpath "string(//testsuite[1]/@tests)" $REPORT_DIR/JUnit_Report.xml)
failures=$(xmllint --xpath "string(//testsuite[1]/@failures)" $REPORT_DIR/JUnit_Report.xml)
errors=$(xmllint --xpath "string(//testsuite[1]/@failures)" $REPORT_DIR/JUnit_Report.xml)
num_tests=$((passed + failures + errors))

payload='
{
    "text":"*Katalon Staging Automation Report*\n\n*Service Name: '$SERVICE_NAME'*\n*Test Name: '$test_name'*\n*Number of test(s): '$num_tests'*\t*Passed: '$passed'*\t*Failures: '$failures'*\t*Errors: '$errors'*\n",
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
SLACK=false
##Loop failed testcase(s)
INDEX=1
while [[ $INDEX -le $failures ]];do
        testcaseName=$(xmllint --xpath "string(//testcase[@status='FAILED'][$INDEX]/@name)" $REPORT_DIR/JUnit_Report.xml)

        attachmentElem='
        {
            "color": "#8b0000",
            "title": "\"'$testcaseName'\""
        }
        '
        payload=$(jq ".attachments += [$attachmentElem]" <<< "$payload")
        SLACK=true
        ((INDEX++))
done
if [[ $SLACK = true ]]
then
    echo $payload
    # curl -i -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_HOOK"
fi
