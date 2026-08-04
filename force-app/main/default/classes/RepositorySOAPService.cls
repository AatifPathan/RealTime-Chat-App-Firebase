global with sharing class RepositorySOAPService {

    webService static List<Repository__c> getRepositories() {
        return [
            SELECT Id,
                   Name,
                   Stars__c,
                   Forks__c,
                   Status__c,
                   Primary_Language__c,
                   Github_URL__c
            FROM Repository__c
        ];
    }

    webService static Repository__c getRepositoryById(Id repositoryId) {
        return [
            SELECT Id,
                   Name,
                   Stars__c,
                   Forks__c,
                   Status__c,
                   Primary_Language__c,
                   Github_URL__c
            FROM Repository__c
            WHERE Id = :repositoryId
            LIMIT 1
        ];
    }

}