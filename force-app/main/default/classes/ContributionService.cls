public with sharing class ContributionService {

    public static List<Contribution__c> getMergedContributions(){

        return [

            SELECT Id,
                   Name,
                   Review_Status__c,
                   Review_Score__c,
                   Contributor__r.Name,
                   Issue__r.Name

            FROM Contribution__c

            WHERE Review_Status__c='Merged'

        ];

    }

}