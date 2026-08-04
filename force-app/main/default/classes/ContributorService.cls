public with sharing class ContributorService {

    public static List<Contributor__c> getContributors() {

        return [
            SELECT Id,
                   Name,
                   Reputation_Score__c,
                   Total_Contributions__c,
                   Current_Rank__c
            FROM Contributor__c
        ];

    }

    public static void updateContributorReputation(Id contributorId, Integer points) {

        Contributor__c contributor = [

            SELECT Id,
                   Reputation_Score__c,
                   Total_Contributions__c,
                   Current_Rank__c

            FROM Contributor__c

            WHERE Id = :contributorId

            LIMIT 1

        ];

        if(contributor.Reputation_Score__c == null)
            contributor.Reputation_Score__c = 0;

        if(contributor.Total_Contributions__c == null)
            contributor.Total_Contributions__c = 0;

        contributor.Reputation_Score__c += points;
        contributor.Total_Contributions__c += 1;

        if(contributor.Reputation_Score__c >= 500){

            contributor.Current_Rank__c = 'Diamond';

        }
        else if(contributor.Reputation_Score__c >= 300){

            contributor.Current_Rank__c = 'Platinum';

        }
        else if(contributor.Reputation_Score__c >= 150){

            contributor.Current_Rank__c = 'Gold';

        }
        else if(contributor.Reputation_Score__c >= 50){

            contributor.Current_Rank__c = 'Silver';

        }
        else{

            contributor.Current_Rank__c = 'Bronze';

        }

        update contributor;

    }

public static List<Contributor__c> getTopContributors(){

    return [

        SELECT Id,
               Name,
               Reputation_Score__c,
               Total_Contributions__c,
               Current_Rank__c

        FROM Contributor__c

        ORDER BY Reputation_Score__c DESC

        LIMIT 10

    ];

}}