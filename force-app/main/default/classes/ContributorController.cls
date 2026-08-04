/**
 * ContributorController
 * Backs `contributors` and `contributorProfile`. Reputation, rank, and
 * total-contribution counts are trigger-maintained (see ContributorService /
 * ContributionTriggerHandler) — read directly, never recomputed here.
 */
public without sharing class ContributorController {

    /**
     * Resolves the Contributor__c record for the running user. Real schema
     * has no explicit User lookup field on Contributor__c, so this assumes
     * the record's Owner is set to the matching user (standard Salesforce
     * "my records" pattern). Shared by ProfileController, SettingsController,
     * SkillController, and BadgeController. Returns null if none found.
     */
    public static Id getCurrentContributorId() {
        List<Contributor__c> matches = [
            SELECT Id FROM Contributor__c WHERE OwnerId = :UserInfo.getUserId() LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0].Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<ContributorItem> getContributors(String searchTerm) {
        String term = '%' + String.escapeSingleQuotes(searchTerm == null ? '' : searchTerm) + '%';

        List<Contributor__c> records = [
            SELECT Id, Name, Experience_Level__c, Current_Rank__c, Reputation_Score__c
            FROM Contributor__c
            WHERE Name LIKE :term
            ORDER BY Reputation_Score__c DESC NULLS LAST
            LIMIT 100
        ];

        Set<Id> contributorIds = new Map<Id, Contributor__c>(records).keySet();

        Map<Id, List<String>> skillsByContributor = new Map<Id, List<String>>();
        for (Contributor_Skill__c cs : [
            SELECT Contributor__c, Skill__r.Name, Primary_Skill__c
            FROM Contributor_Skill__c
            WHERE Contributor__c IN :contributorIds
            ORDER BY Primary_Skill__c DESC
        ]) {
            if (!skillsByContributor.containsKey(cs.Contributor__c)) {
                skillsByContributor.put(cs.Contributor__c, new List<String>());
            }
            if (skillsByContributor.get(cs.Contributor__c).size() < 3) {
                skillsByContributor.get(cs.Contributor__c).add(cs.Skill__r.Name);
            }
        }

        Map<Id, Integer> repoCountByContributor = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Contributor__c contributorId, COUNT_DISTINCT(Issue__r.Repository__c) repoCount
            FROM Contribution__c
            WHERE Contributor__c IN :contributorIds
            GROUP BY Contributor__c
        ]) {
            repoCountByContributor.put((Id) ar.get('contributorId'), (Integer) ar.get('repoCount'));
        }

        Map<Id, Integer> badgeCountByContributor = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Contributor__c contributorId, COUNT(Id) badgeCount
            FROM Badge__c
            WHERE Contributor__c IN :contributorIds
            GROUP BY Contributor__c
        ]) {
            badgeCountByContributor.put((Id) ar.get('contributorId'), (Integer) ar.get('badgeCount'));
        }

        List<ContributorItem> results = new List<ContributorItem>();
        for (Contributor__c c : records) {
            ContributorItem item = new ContributorItem();
            item.id = c.Id;
            item.name = c.Name;
            item.role = (c.Experience_Level__c == null ? '' : c.Experience_Level__c) +
                (c.Current_Rank__c == null ? '' : ' \u00B7 ' + c.Current_Rank__c);
            item.reputation = c.Reputation_Score__c == null ? 0 : Integer.valueOf(c.Reputation_Score__c);
            item.skills = skillsByContributor.containsKey(c.Id) ? skillsByContributor.get(c.Id) : new List<String>();
            item.repoCount = repoCountByContributor.containsKey(c.Id) ? repoCountByContributor.get(c.Id) : 0;
            item.badgeCount = badgeCountByContributor.containsKey(c.Id) ? badgeCountByContributor.get(c.Id) : 0;
            results.add(item);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static ContributorProfileData getContributorProfile(Id contributorId) {
        Contributor__c c = [
            SELECT Id, Name, Experience_Level__c, Current_Rank__c, Bio__c,
                   Reputation_Score__c, GitHub_Username__c, CreatedDate
            FROM Contributor__c
            WHERE Id = :contributorId
            LIMIT 1
        ];

        ContributorProfileData data = new ContributorProfileData();
        data.id = c.Id;
        data.name = c.Name;
        data.role = (c.Experience_Level__c == null ? '' : c.Experience_Level__c) +
            (c.Current_Rank__c == null ? '' : ' \u00B7 ' + c.Current_Rank__c);
        data.bio = c.Bio__c;
        data.reputation = c.Reputation_Score__c == null ? 0 : Integer.valueOf(c.Reputation_Score__c);
        data.githubUsername = c.GitHub_Username__c;
        data.joinedDate = Date.valueOf(c.CreatedDate);

        data.skills = new List<SkillLevel>();
        for (Contributor_Skill__c cs : [
            SELECT Skill__r.Name, Proficiency_Level__c
            FROM Contributor_Skill__c
            WHERE Contributor__c = :contributorId
            ORDER BY Primary_Skill__c DESC
        ]) {
            SkillLevel sl = new SkillLevel();
            sl.name = cs.Skill__r.Name;
            sl.level = proficiencyToPercent(cs.Proficiency_Level__c);
            data.skills.add(sl);
        }

        data.repositories = new List<RepoContribution>();
        for (AggregateResult ar : [
            SELECT Issue__r.Repository__c repoId, Issue__r.Repository__r.Name repoName, COUNT(Id) cnt
            FROM Contribution__c
            WHERE Contributor__c = :contributorId
            GROUP BY Issue__r.Repository__c, Issue__r.Repository__r.Name
            ORDER BY COUNT(Id) DESC
            LIMIT 6
        ]) {
            RepoContribution rc = new RepoContribution();
            rc.id = (Id) ar.get('repoId');
            rc.name = (String) ar.get('repoName');
            rc.commits = (Integer) ar.get('cnt');
            data.repositories.add(rc);
        }

        data.projects = new List<ProjectRole>();
        Set<Id> projectIds = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Issue__r.Repository__r.Project__c projectId
            FROM Contribution__c
            WHERE Contributor__c = :contributorId AND Issue__r.Repository__r.Project__c != null
            GROUP BY Issue__r.Repository__r.Project__c
            LIMIT 6
        ]) {
            projectIds.add((Id) ar.get('projectId'));
        }
        if (!projectIds.isEmpty()) {
            for (Project__c p : [SELECT Id, Name FROM Project__c WHERE Id IN :projectIds]) {
                ProjectRole pr = new ProjectRole();
                pr.id = p.Id;
                pr.name = p.Name;
                pr.role = 'Contributor';
                data.projects.add(pr);
            }
        }

        data.badges = new List<BadgeItem>();
        for (Badge__c b : [
            SELECT Badge_Type__c, Points__c
            FROM Badge__c
            WHERE Contributor__c = :contributorId
            ORDER BY Awarded_Date__c DESC
        ]) {
            BadgeItem bi = new BadgeItem();
            bi.name = b.Badge_Type__c;
            bi.icon = BadgeController.iconForBadgeType(b.Badge_Type__c);
            data.badges.add(bi);
        }

        data.timeline = new List<TimelineItem>();
        for (Contribution__c con : [
            SELECT Id, Review_Status__c, Issue__r.Name, CreatedDate
            FROM Contribution__c
            WHERE Contributor__c = :contributorId
            ORDER BY CreatedDate DESC
            LIMIT 6
        ]) {
            TimelineItem ti = new TimelineItem();
            ti.id = con.Id;
            ti.text = con.Review_Status__c + (con.Issue__r != null ? ' \u2014 "' + con.Issue__r.Name + '"' : '');
            ti.timestamp = con.CreatedDate;
            data.timeline.add(ti);
        }

        return data;
    }

    public static Integer proficiencyToPercent(String proficiency) {
        Map<String, Integer> levelMap = new Map<String, Integer>{
            'Beginner' => 25, 'Intermediate' => 50, 'Advanced' => 75, 'Expert' => 100
        };
        return levelMap.containsKey(proficiency) ? levelMap.get(proficiency) : 0;
    }

    // ---------- DTOs ----------

    public class ContributorItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
        @AuraEnabled public Integer reputation;
        @AuraEnabled public List<String> skills;
        @AuraEnabled public Integer repoCount;
        @AuraEnabled public Integer badgeCount;
    }

    public class ContributorProfileData {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
        @AuraEnabled public String bio;
        @AuraEnabled public Integer reputation;
        @AuraEnabled public String githubUsername;
        @AuraEnabled public Date joinedDate;
        @AuraEnabled public List<SkillLevel> skills;
        @AuraEnabled public List<RepoContribution> repositories;
        @AuraEnabled public List<ProjectRole> projects;
        @AuraEnabled public List<BadgeItem> badges;
        @AuraEnabled public List<TimelineItem> timeline;
    }

    public class SkillLevel {
        @AuraEnabled public String name;
        @AuraEnabled public Integer level;
    }

    public class RepoContribution {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer commits;
    }

    public class ProjectRole {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
    }

    public class BadgeItem {
        @AuraEnabled public String name;
        @AuraEnabled public String icon;
    }

    public class TimelineItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String text;
        @AuraEnabled public Datetime timestamp;
    }
}
