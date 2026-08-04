@IsTest
private class ContributorServiceTest {

    @TestSetup
    static void setupData(){

        Contributor__c contributor = new Contributor__c(

            Name = 'John Doe',
            Email__c = 'john@test.com',
            Reputation_Score__c = 0,
            Total_Contributions__c = 0

        );

        insert contributor;

    }

    @IsTest
    static void testUpdateContributorReputation(){

        Contributor__c contributor = [

            SELECT Id

            FROM Contributor__c

            LIMIT 1

        ];

        Test.startTest();

        ContributorService.updateContributorReputation(

            contributor.Id,
            60

        );

        Test.stopTest();

        contributor = [

            SELECT Reputation_Score__c,
                   Total_Contributions__c,
                   Current_Rank__c

            FROM Contributor__c

            WHERE Id = :contributor.Id

        ];

        System.assertEquals(

            60,
            contributor.Reputation_Score__c

        );

        System.assertEquals(

            1,
            contributor.Total_Contributions__c

        );

        System.assertEquals(

            'Silver',
            contributor.Current_Rank__c

        );

    }

    @IsTest
    static void testGetContributors(){

        Test.startTest();

        List<Contributor__c> contributors =

            ContributorService.getContributors();

        Test.stopTest();

        System.assertEquals(

            1,
            contributors.size()

        );

    }

    @IsTest
    static void testGetTopContributors(){

        Test.startTest();

        List<Contributor__c> contributors =

            ContributorService.getTopContributors();

        Test.stopTest();

        System.assertEquals(

            1,
            contributors.size()

        );

    }

}