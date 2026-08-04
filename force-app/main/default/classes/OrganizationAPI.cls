@RestResource(urlMapping='/opencore/organizations/*')
global with sharing class OrganizationAPI {

    @HttpGet
    global static List<Organization__c> getOrganizations() {

        return [

            SELECT
                Id,
                Name,
                Description__c,
                Website__c,
                Active__c,
                Active_Contributors__c,
                Total_Repositories__c,
                Technology_Stack__c,
                Primary_Mentor__c

            FROM Organization__c

            ORDER BY Name

        ];

    }

}