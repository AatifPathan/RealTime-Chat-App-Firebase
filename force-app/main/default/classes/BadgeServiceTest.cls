@IsTest
private class BadgeServiceTest {

    @TestSetup
    static void setupData(){

        Contributor__c contributor = new Contributor__c(

            Name = 'John Doe',
            Email__c = 'john@test.com',
            Reputation_Score__c = 100,
            Total_Contributions__c = 5

        );

        insert contributor;

    }

    @IsTest
    static void testAwardBadges(){

        Contributor__c contributor = [

            SELECT Id

            FROM Contributor__c

            LIMIT 1

        ];

        Test.startTest();

        BadgeService.awardBadges(contributor.Id);

        Test.stopTest();

        List<Badge__c> badges = [

            SELECT Name

            FROM Badge__c

            WHERE Contributor__c = :contributor.Id

        ];

        System.assertEquals(

            2,
            badges.size()

        );

    }

    @IsTest
    static void testGetBadges(){

        Test.startTest();

        List<Badge__c> badges = BadgeService.getBadges();

        Test.stopTest();

        System.assertNotEquals(

            null,
            badges

        );

    }

}