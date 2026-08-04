public with sharing class BadgeService {

    public static List<Badge__c> getBadges(){

        return [

            SELECT Id,
                   Name,
                   Badge_Type__c,
                   Points__c,
                   Awarded_Date__c,
                   Contributor__c

            FROM Badge__c

        ];

    }

    public static void awardBadges(Id contributorId){

        Contributor__c contributor = [

            SELECT Id,
                   Name,
                   Reputation_Score__c,
                   Total_Contributions__c

            FROM Contributor__c

            WHERE Id = :contributorId

            LIMIT 1

        ];

        List<Badge__c> existingBadges = [

            SELECT Name

            FROM Badge__c

            WHERE Contributor__c = :contributorId

        ];

        Set<String> earned = new Set<String>();

        for(Badge__c b : existingBadges){
            earned.add(b.Name);
        }

        List<Badge__c> newBadges = new List<Badge__c>();

        // First Contribution Badge
        if(contributor.Total_Contributions__c >= 1 &&
           !earned.contains('First Contribution')){

            newBadges.add(new Badge__c(

                Name='First Contribution',
                Contributor__c=contributor.Id,
                Badge_Type__c='First Contribution',
                Points__c=10,
                Awarded_Date__c=Date.today(),
                Active__c=true

            ));

        }

        // Top Contributor Badge
        if(contributor.Total_Contributions__c >= 5 &&
           !earned.contains('Top Contributor')){

            newBadges.add(new Badge__c(

                Name='Top Contributor',
                Contributor__c=contributor.Id,
                Badge_Type__c='Top Contributor',
                Points__c=50,
                Awarded_Date__c=Date.today(),
                Active__c=true

            ));

        }

        // Open Source Champion Badge
        if(contributor.Total_Contributions__c >= 25 &&
           !earned.contains('Open Source Champion')){

            newBadges.add(new Badge__c(

                Name='Open Source Champion',
                Contributor__c=contributor.Id,
                Badge_Type__c='Open Source Champion',
                Points__c=150,
                Awarded_Date__c=Date.today(),
                Active__c=true

            ));

        }

        if(contributor.Total_Contributions__c >= 50 &&
           !earned.contains('Community Helper')){

            newBadges.add(new Badge__c(

                Name='Community Helper',
                Contributor__c=contributor.Id,
                Badge_Type__c='Community Helper',
                Points__c=300,
                Awarded_Date__c=Date.today(),
                Active__c=true

            ));

        }

        if(!newBadges.isEmpty()){
            insert newBadges;
        }

    }

}