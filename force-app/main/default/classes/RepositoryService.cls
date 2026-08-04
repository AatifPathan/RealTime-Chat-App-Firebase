public with sharing class RepositoryService {

    // Returns all active repositories
    public static List<Repository__c> getActiveRepositories() {

        return [
            SELECT Id,
                   Name,
                   Stars__c,
                   Forks__c,
                   Open_Issues__c,
                   Primary_Language__c,
                   Difficulty_Level__c,
                   Status__c,
                   Organization__r.Name,
                   Project__r.Name
            FROM Repository__c
            WHERE Active__c = true
            ORDER BY Stars__c DESC
        ];

    }

    // Updates Open Issues count
    public static void updateOpenIssues(Id repositoryId){

        Integer openIssueCount = [

            SELECT COUNT()

            FROM Issue__c

            WHERE Repository__c = :repositoryId
            AND Status__c != 'Closed'

        ];

        Repository__c repo = new Repository__c(

            Id = repositoryId,
            Open_Issues__c = openIssueCount

        );

        update repo;

    }

}