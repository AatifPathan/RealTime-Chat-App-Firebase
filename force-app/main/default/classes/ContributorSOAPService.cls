global with sharing class ContributorSOAPService {

    webService static List<Contributor__c> getContributors() {

        return [
            SELECT Id,
                   Name,
                   Email__c,
                   Country__c,
                   Primary_Skill__c,
                   Reputation_Score__c
            FROM Contributor__c
        ];
    }

    webService static Contributor__c getContributor(Id contributorId) {

        return [
            SELECT Id,
                   Name,
                   Email__c,
                   Country__c,
                   Primary_Skill__c,
                   Reputation_Score__c
            FROM Contributor__c
            WHERE Id=:contributorId
            LIMIT 1
        ];
    }

}