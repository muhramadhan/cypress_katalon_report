#!/bin/bash
mapping_jenkins_url(){
    MAPPING_JENKINS["order app"]="https://jenkins-staging.tokopedia.com/job/go%20-%20orderapp/job/Pipeline/"
    MAPPING_JENKINS["brand store"]="https://jenkins-staging.tokopedia.com/job/go%20-%20brand%20store/job/Pipeline/"
    MAPPING_JENKINS["officialstore-home"]="https://jenkins-staging.tokopedia.com/job/Officialstore%20Home/job/Pipeline/"
    MAPPING_JENKINS["brand store"]="https://jenkins-staging.tokopedia.com/job/go%20-%20brand%20store/job/Pipeline/"
    MAPPING_JENKINS["os-seller"]="https://jenkins-staging.tokopedia.com/job/os-seller/job/Pipeline/"
    MAPPING_JENKINS["fulfillment service"]="https://jenkins-staging.tokopedia.com/job/go%20-%20fulfillment%20service/"
    MAPPING_JENKINS["keroaddr"]="https://jenkins-staging.tokopedia.com/job/go%20-%20kero-addr/job/Pipeline/"
    MAPPING_JENKINS["gandalf/kero"]="https://jenkins-staging.tokopedia.com/job/go%20-%20kero/job/Pipeline/"
    MAPPING_JENKINS["warehouse"]="https://jenkins-staging.tokopedia.com/job/warehouse/job/Pipeline/"
    MAPPING_JENKINS["kero"]="https://jenkins-staging.tokopedia.com/job/go%20-%20kero/job/Pipeline/"
    MAPPING_JENKINS["category"]="https://jenkins-staging.tokopedia.com/job/go%20-%20hades/job/Pipeline/"
    MAPPING_JENKINS["search microservice"]="https://jenkins-staging.tokopedia.com/job/go%20-%20search%20microservice/job/Pipeline"
    MAPPING_JENKINS["jerry"]="https://jenkins-staging.tokopedia.com/job/go%20-%20reputation/job/Pipeline"
    MAPPING_JENKINS["campaign"]="https://jenkins-staging.tokopedia.com/job/go%20-%20campaign/job/Pipeline/"
    MAPPING_JENKINS["gold merchant"]="https://jenkins-staging.tokopedia.com/view/all/job/go-goldmerchant/job/Pipeline/"
    MAPPING_JENKINS["resolution"]="https://jenkins-staging.tokopedia.com/job/go%20-%20resolution/job/Pipeline/"
    MAPPING_JENKINS["brand store"]="https://jenkins-staging.tokopedia.com/job/go%20-%20brand%20store/job/Pipeline/"
    MAPPING_JENKINS["officialstore-home"]="https://jenkins-staging.tokopedia.com/job/Officialstore%20Home/job/Pipeline/"
    MAPPING_JENKINS["os-seller"]="https://jenkins-staging.tokopedia.com/job/os-seller/job/Pipeline/"
    MAPPING_JENKINS["openapi"]="https://jenkins-staging.tokopedia.com/job/openapi/job/Pipeline/"
    MAPPING_JENKINS["krabs"]="https://jenkins-staging.tokopedia.com/job/go%20-%20toko/job/Pipeline/"
}
usage(){
    echo "Usage: [-r | --reportDir ReportPath] [-c | --config configFile] [-s | --service service_name]"
}

#preparing hash table
declare -A MAPPING_JENKINS
mapping_jenkins_url

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

if [ ! -f $REPORT_MOCHAWESOME_SERVICE_PATH/mochawesome.json ]
then
    echo "Error: There is no report file in $REPORT_MOCHAWESOME_SERVICE_PATH"
    exit 1
fi

MERGED=false
# echo "Merging mochawesome jsons"
mkdir -p $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged
npx mochawesome-merge --reportDir $REPORT_MOCHAWESOME_SERVICE_PATH > $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged/mochawesome-merge.json
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

test_name=$(jq -r '.env.test_name' cypress/config/$TEST_CONFIG_FILEPATH.json)
test_env=$(jq -r '.env.env_name' cypress/config/$TEST_CONFIG_FILEPATH.json)
num_tests=$(jq -r '.stats.tests' $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged/mochawesome-merge.json)
num_suites=$(jq -r '.stats.suites' $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged/mochawesome-merge.json)
failures=$(jq -r '.stats.failures' $REPORT_MOCHAWESOME_SERVICE_PATH/../${FOLDER_TIMESTAMP}_merged/mochawesome-merge.json)
payload=

service_lower=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]')

if [ -n "$test_name" ] && [ -n "$test_env" ]
then
    payload='
    {
        "text":"*Cypress Staging Automation Report*\n\n*Service Name: '$SERVICE_NAME'*\n*Test Name: '$test_name'*\n*Env: '$test_env'*\n*Number of test suite(s): '$num_suites'*\t*Number of test(s): '$num_tests'*\n*Failures: '$failures'*\n",
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
        "text":"*Cypress Staging Automation Report*\n\n*Service Name: '$SERVICE_NAME'*\n*Number of test suite(s): '$num_suites'*\t*Number of test(s): '$num_tests'*\n*Failures: '$failures'*\n",
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
    for j in $(echo $i | base64 --decode | jq -r ".tests[] | @base64")
    do    
        decodedTestCase=$(echo $j | base64 --decode)
        # echo $decodedTestCase | tr '\r\n' ' ' | jq -r ".title"
        if [ $(echo $decodedTestCase | tr '\r\n' ' ' | jq -r ".fail") = true ]
        then
            pass=false
            slack=true
            testCaseTitle=$(echo $decodedTestCase | tr '\r\n' ' ' | jq -r ".title")
            errMsg=$(echo $decodedTestCase | tr '\r\n' ' ' | jq -r ".err.message" | tr '\n' ' ' | cut -c1-60)
            footerElem+='-'$testCaseTitle': '$(echo $errMsg | tr -d "\"'")'\n'
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
            "footer": "'$(echo $footerElem | sed 's/\"/\\"/g' )'"
        }
        '
        payload=$(jq ".attachments += [$attachmentElem]" <<< "$payload")
    fi
    ((indexSuite++))
done



if [ $slack = true ]
then
    echo $payload
    # curl -i -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_HOOK"
fi

#https://hooks.slack.com/services/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
#Cleaning report files
# rm $REPORT_MOCHAWESOME_SERVICE_PATH/*.json
# rm $REPORT_MOCHAWESOME_SERVICE_PATH/../merge/*.json
