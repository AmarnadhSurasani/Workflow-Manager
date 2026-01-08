/* SAS templated code goes here */

cas ;
caslib _all_ assign;


%global library_name training_data newChampionModel;

%put &library_name;

%put &training_data;

%put &externalProjectId;
proc python;
    submit;
import json
import requests
import time

#Ensure the correct port is set for your environment
#The default port for TLS enabled systems is 443
#The default port for non-TLS enable systems is 80
urlPrefix = "https://sasviyaind.sas.com"

library_name= SAS.symget('library_name')
training_data=SAS.symget('training_data')
externalProjectId=SAS.symget('externalProjectId')

username ='demo'
password = 'Orion123'

url = f"{urlPrefix}/SASLogon/oauth/token" 

authBody = 'grant_type=password&username=%s&password=%s' %(username, password)

headersAuth={'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded'}

r =  requests.request('POST', url, data= authBody, headers=headersAuth, auth=('sas.ec', ''),verify=False)

token = r.json()['access_token']

print(token)


projectId = f"{externalProjectId}"
dataUri = f"/dataTables/dataSources/cas~fs~cas-shared-default~fs~{library_name}/tables/{training_data}"
oauthToken = "Bearer "+token

print(oauthToken)
#Perform Batch Retrain
retrainingUrl = urlPrefix + "/dataMiningProjectResources/projects/" + projectId + "/retrainJobs"
dmprRetrainingUrl = urlPrefix + "/dataMiningProjectResources/projects/" + projectId + "/retrainJobs"
querystring = {"action":"batch", "dataUri":dataUri}
payload = ""
headers = {
    "authorization": oauthToken,
    "accept": "application/vnd.sas.job.execution.job+json",
}
response = requests.request("POST", retrainingUrl, data=payload, headers=headers, params=querystring,verify=False)
print(response.text)

#Wait before starting to look for the job
time.sleep(10)

#Get Current Retraining Job
currentRetrainingJobUrl = retrainingUrl + "/@currentJob"
payload = ""
headers = {
    "authorization": oauthToken,
    "accept": "application/vnd.sas.job.execution.job+json",
}
response = requests.request("GET", currentRetrainingJobUrl, data=payload, headers=headers,verify=False)
response_txt = response.text
job = json.loads(response_txt)

jobLinks = job["links"]

for link in jobLinks:
    if link["rel"] == "self":
        selfLink = link
    break;

attempts = 0
maxAttempts = 300

while True:
    attempts = attempts + 1
    selfLinkUrl = urlPrefix + selfLink["uri"]
    payload = ""
    headers = {
        "accept": "application/vnd.sas.job.execution.job+json",
        "authorization": oauthToken
    }
    response = requests.request("GET", selfLinkUrl, data=payload, headers=headers,verify=False)

    response_txt = response.text
    job = json.loads(response_txt)

    jobState = job["state"]
    print("Retraining job state is "+ jobState)

    if jobState == "completed" or jobState == "canceled" or jobState == "failed" or jobState == "timedOut" or attempts > maxAttempts:
        break;
    #Wait for 10 seconds before polling the job again
    time.sleep(10)

print("Final retraining job state is " + jobState)

#Get Champion
if jobState == "completed":
    championUri = dmprRetrainingUrl + "/@lastJob/champion"
    payload = ""
    headers = {
        "authorization": oauthToken,
        "accept": "application/vnd.sas.analytics.data.mining.model+json",
    }
    response = requests.request("GET", championUri, data=payload, headers=headers, params=querystring,verify=False)
    #If the project has a champion model, it will be printed
    if response.status_code == requests.codes.ok:
        response_txt = response.text
        model = json.loads(response_txt)
        projectChampion = model["name"]
        SAS.symput('newProjectChampion', projectChampion)
        print("Project champion model is " + projectChampion)
endsubmit;

