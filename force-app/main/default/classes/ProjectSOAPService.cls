global with sharing class ProjectSOAPService {

    webService static List<Project__c> getProjects() {

        return [
            SELECT Id,
                   Name,
                   Status__c,
                   Active__c,
                   Start_Date__c,
                   End_Date__c
            FROM Project__c
        ];
    }

    webService static Project__c getProject(Id projectId) {

        return [
            SELECT Id,
                   Name,
                   Status__c,
                   Active__c,
                   Start_Date__c,
                   End_Date__c
            FROM Project__c
            WHERE Id=:projectId
            LIMIT 1
        ];
    }

}