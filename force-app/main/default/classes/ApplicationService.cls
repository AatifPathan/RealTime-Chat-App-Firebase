public with sharing class ApplicationService {

    public static List<Application__c> getPendingApplications(){

        return [

            SELECT Id,
                   Name,
                   Status__c,
                   Applied_On__c,
                   Contributor__r.Name,
                   Issue__r.Name

            FROM Application__c

            WHERE Status__c='Pending'

        ];

    }

}