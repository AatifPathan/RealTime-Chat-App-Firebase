/**
 * BadgeController
 * Backs `badges`. Badge__c in this schema is an *awarded* badge (one row
 * per contributor per badge), not a catalog + junction. The "locked/unlocked
 * with progress" catalog view is built here from the 8 real Badge_Type__c
 * picklist values, cross-referenced against what the current contributor
 * has actually been awarded (via Badge__c) — badges are never invented or
 * awarded by this controller; awarding is entirely handled by your existing
 * BadgeService/ContributionTriggerHandler.
 */
public without sharing class BadgeController {

    // Mirrors the thresholds in BadgeService.awardBadges exactly, so
    // progress bars for locked badges reflect the real unlock logic.
    private static final Map<String, Integer> AUTO_AWARD_THRESHOLDS = new Map<String, Integer>{
        'First Contribution' => 1,
        'Top Contributor' => 5,
        'Open Source Champion' => 25,
        'Community Helper' => 50
    };

    private static final List<String> ALL_BADGE_TYPES = new List<String>{
        'First Contribution', 'Top Contributor', 'Bug Hunter', 'Documentation Hero',
        'Code Reviewer', 'Open Source Champion', 'Mentor Choice', 'Community Helper'
    };

    @AuraEnabled(cacheable=true)
    public static List<BadgeItem> getBadgesForCurrentUser() {
        Id contributorId = ContributorController.getCurrentContributorId();

        Set<String> earnedTypes = new Set<String>();
        Integer totalContributions = 0;
        if (contributorId != null) {
            for (Badge__c b : [SELECT Badge_Type__c FROM Badge__c WHERE Contributor__c = :contributorId]) {
                earnedTypes.add(b.Badge_Type__c);
            }
            Contributor__c c = [SELECT Total_Contributions__c FROM Contributor__c WHERE Id = :contributorId LIMIT 1];
            totalContributions = c.Total_Contributions__c == null ? 0 : Integer.valueOf(c.Total_Contributions__c);
        }

        List<BadgeItem> results = new List<BadgeItem>();
        for (String badgeType : ALL_BADGE_TYPES) {
            BadgeItem item = new BadgeItem();
            item.id = badgeType;
            item.name = badgeType;
            item.icon = iconForBadgeType(badgeType);
            item.unlocked = earnedTypes.contains(badgeType);

            if (item.unlocked) {
                item.progress = 100;
                item.description = 'Unlocked';
            } else if (AUTO_AWARD_THRESHOLDS.containsKey(badgeType)) {
                Integer threshold = AUTO_AWARD_THRESHOLDS.get(badgeType);
                item.progress = Math.min(95, (Integer) Math.round((totalContributions * 100.0) / threshold));
                item.description = 'Awarded automatically at ' + threshold + ' contribution' + (threshold == 1 ? '' : 's') +
                    ' (currently ' + totalContributions + ')';
            } else {
                item.progress = 0;
                item.description = 'Awarded by a mentor';
            }
            results.add(item);
        }
        return results;
    }

    public static String iconForBadgeType(String badgeType) {
        Map<String, String> icons = new Map<String, String>{
            'First Contribution' => '⌥',
            'Top Contributor' => '★',
            'Bug Hunter' => '◆',
            'Documentation Hero' => '▤',
            'Code Reviewer' => '✓',
            'Open Source Champion' => '◎',
            'Mentor Choice' => '◍',
            'Community Helper' => '◈'
        };
        return icons.containsKey(badgeType) ? icons.get(badgeType) : '◆';
    }

    // ---------- DTO ----------

    public class BadgeItem {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public String icon;
        @AuraEnabled public Boolean unlocked;
        @AuraEnabled public Integer progress;
    }
}
