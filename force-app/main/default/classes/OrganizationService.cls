public with sharing class OrganizationService {

    // Returns all organizations
    public static List<Organization__c> getOrganizations(){

        return [

            SELECT Id,
                   Name,
                   Active__c,
                   Total_Repositories__c,
                   Active_Contributors__c,
                   Technology_Stack__c

            FROM Organization__c

            ORDER BY Name

        ];

    }

    // Updates Total Repositories
    public static void updateRepositoryCount(Id organizationId){

        if(organizationId == null){
            return;
        }

        Integer repoCount = [

            SELECT COUNT()

            FROM Repository__c

            WHERE Organization__c = :organizationId

        ];

        update new Organization__c(

            Id = organizationId,
            Total_Repositories__c = repoCount

        );

    }

    // Updates Active Contributors
    public static void updateActiveContributors(Id organizationId){

        if(organizationId == null){
            return;
        }

        Set<Id> contributorIds = new Set<Id>();

        List<Contribution__c> contributions = [

            SELECT Contributor__c

            FROM Contribution__c

            WHERE Review_Status__c IN ('Approved','Merged')
            AND Issue__r.Repository__r.Organization__c = :organizationId

        ];

        for(Contribution__c contribution : contributions){

            if(contribution.Contributor__c != null){

                contributorIds.add(contribution.Contributor__c);

            }

        }

        update new Organization__c(

            Id = organizationId,
            Active_Contributors__c = contributorIds.size()

        );

    }

}