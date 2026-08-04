public with sharing class DashboardService {

    public static Integer totalRepositories(){

        return [

            SELECT COUNT()

            FROM Repository__c

        ];

    }

    public static Integer totalContributors(){

        return [

            SELECT COUNT()

            FROM Contributor__c

        ];

    }

}