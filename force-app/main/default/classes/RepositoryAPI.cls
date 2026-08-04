@RestResource(urlMapping='/opencore/repositories/*')
global with sharing class RepositoryAPI {

    @HttpGet
    global static List<Repository__c> getRepositories() {

        return [
            SELECT
                Id,
                Name,
                Description__c,
                Primary_Language__c,
                Difficulty_Level__c,
                Github_URL__c,
                Stars__c,
                Forks__c,
                Watchers__c,
                Open_Issues__c,
                Status__c,
                Visibility__c,
                Active__c,
                Topics__c,
                License__c,
                Created_On_GitHub__c,
                Last_Synced__c,
                Organization__r.Name,
                Project__r.Name
            FROM Repository__c
            ORDER BY Name
        ];
    }

}