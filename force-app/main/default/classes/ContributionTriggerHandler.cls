public with sharing class ContributionTriggerHandler {

    public static void afterInsert(List<Contribution__c> newContributions) {

        for(Contribution__c contribution : newContributions){

            Integer points = getPoints(contribution.Review_Status__c);

            if(contribution.Contributor__c != null){

                ContributorService.updateContributorReputation(
                    contribution.Contributor__c,
                    points
                );

                BadgeService.awardBadges(
                    contribution.Contributor__c
                );

            }

            if((contribution.Review_Status__c == 'Approved' ||
                contribution.Review_Status__c == 'Merged') &&
                contribution.Issue__c != null){

                Issue__c issue = [

                    SELECT Repository__r.Organization__c

                    FROM Issue__c

                    WHERE Id = :contribution.Issue__c

                    LIMIT 1

                ];

                if(issue.Repository__r.Organization__c != null){

                    OrganizationService.updateActiveContributors(
                        issue.Repository__r.Organization__c
                    );

                }

            }

        }

    }

    public static void afterUpdate(
        List<Contribution__c> newContributions,
        Map<Id, Contribution__c> oldMap
    ) {

        for(Contribution__c contribution : newContributions){

            Contribution__c oldContribution = oldMap.get(contribution.Id);

            if(contribution.Review_Status__c != oldContribution.Review_Status__c){

                Integer points = getPoints(contribution.Review_Status__c);

                if(contribution.Contributor__c != null){

                    ContributorService.updateContributorReputation(
                        contribution.Contributor__c,
                        points
                    );

                    BadgeService.awardBadges(
                        contribution.Contributor__c
                    );

                }

                if((contribution.Review_Status__c == 'Approved' ||
                    contribution.Review_Status__c == 'Merged') &&
                    contribution.Issue__c != null){

                    Issue__c issue = [

                        SELECT Repository__r.Organization__c

                        FROM Issue__c

                        WHERE Id = :contribution.Issue__c

                        LIMIT 1

                    ];

                    if(issue.Repository__r.Organization__c != null){

                        OrganizationService.updateActiveContributors(
                            issue.Repository__r.Organization__c
                        );

                    }

                }

            }

        }

    }
    private static void updateOrganizations(Set<Id> issueIds){

    if(issueIds.isEmpty()){
        return;
    }

    Set<Id> organizationIds = new Set<Id>();

    for(Issue__c issue : [

        SELECT Repository__r.Organization__c

        FROM Issue__c

        WHERE Id IN :issueIds

    ]){

        if(issue.Repository__r.Organization__c != null){

            organizationIds.add(issue.Repository__r.Organization__c);

        }

    }

    for(Id organizationId : organizationIds){

        OrganizationService.updateActiveContributors(
            organizationId
        );

    }

}

    private static Integer getPoints(String status){

        if(status == 'Submitted')
            return 2;

        if(status == 'Under Review')
            return 5;

        if(status == 'Approved')
            return 20;

        if(status == 'Merged')
            return 50;

        if(status == 'Changes Requested')
            return -5;

        if(status == 'Rejected')
            return -10;

        return 0;

    }

}