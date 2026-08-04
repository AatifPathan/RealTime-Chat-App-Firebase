/**
 * ProfileController
 * Backs `profile`. Resolves the running user's Contributor__c (via OwnerId)
 * and returns profile stats read directly from trigger-maintained fields
 * (Reputation_Score__c, Total_Contributions__c) plus skills/badges/projects/
 * repositories derived the same way as ContributorController.
 */
public with sharing class ProfileController {

    @AuraEnabled(cacheable=true)
    public static ProfileData getMyProfile() {
        Id contributorId = ContributorController.getCurrentContributorId();
        if (contributorId == null) {
            throw new AuraHandledException('No Contributor record is linked to your Salesforce user. Ask an admin to check record ownership.');
        }

        Contributor__c c = [
            SELECT Id, Name, Experience_Level__c, Current_Rank__c, Reputation_Score__c, Total_Contributions__c
            FROM Contributor__c
            WHERE Id = :contributorId
            LIMIT 1
        ];

        ProfileData data = new ProfileData();
        data.id = c.Id;
        data.name = c.Name;
        data.title = c.Current_Rank__c;
        data.role = c.Experience_Level__c;
        data.reputation = c.Reputation_Score__c == null ? 0 : Integer.valueOf(c.Reputation_Score__c);
        data.contributionCount = c.Total_Contributions__c == null ? 0 : Integer.valueOf(c.Total_Contributions__c);
        data.badgeCount = [SELECT COUNT() FROM Badge__c WHERE Contributor__c = :contributorId];

        Set<Id> repoIds = new Set<Id>();
        for (Contribution__c con : [SELECT Issue__r.Repository__c FROM Contribution__c WHERE Contributor__c = :contributorId AND Issue__r.Repository__c != null]) {
            repoIds.add(con.Issue__r.Repository__c);
        }
        data.repositoryCount = repoIds.size();

        data.skills = new List<ContributorController.SkillLevel>();
        for (Contributor_Skill__c cs : [
            SELECT Skill__r.Name, Proficiency_Level__c
            FROM Contributor_Skill__c
            WHERE Contributor__c = :contributorId
            ORDER BY Primary_Skill__c DESC
            LIMIT 6
        ]) {
            ContributorController.SkillLevel sl = new ContributorController.SkillLevel();
            sl.name = cs.Skill__r.Name;
            sl.level = ContributorController.proficiencyToPercent(cs.Proficiency_Level__c);
            data.skills.add(sl);
        }

        data.badges = new List<ContributorController.BadgeItem>();
        for (Badge__c b : [
            SELECT Badge_Type__c
            FROM Badge__c
            WHERE Contributor__c = :contributorId
            ORDER BY Awarded_Date__c DESC
            LIMIT 6
        ]) {
            ContributorController.BadgeItem bi = new ContributorController.BadgeItem();
            bi.name = b.Badge_Type__c;
            bi.icon = BadgeController.iconForBadgeType(b.Badge_Type__c);
            data.badges.add(bi);
        }

        data.projects = new List<ContributorController.ProjectRole>();
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
                ContributorController.ProjectRole pr = new ContributorController.ProjectRole();
                pr.id = p.Id;
                pr.name = p.Name;
                pr.role = 'Contributor';
                data.projects.add(pr);
            }
        }

        data.repositories = new List<ContributorController.RepoContribution>();
        for (AggregateResult ar : [
            SELECT Issue__r.Repository__c repoId, Issue__r.Repository__r.Name repoName, COUNT(Id) cnt
            FROM Contribution__c
            WHERE Contributor__c = :contributorId
            GROUP BY Issue__r.Repository__c, Issue__r.Repository__r.Name
            ORDER BY COUNT(Id) DESC
            LIMIT 6
        ]) {
            ContributorController.RepoContribution rc = new ContributorController.RepoContribution();
            rc.id = (Id) ar.get('repoId');
            rc.name = (String) ar.get('repoName');
            rc.commits = (Integer) ar.get('cnt');
            data.repositories.add(rc);
        }

        return data;
    }

    // ---------- DTO ----------

    public class ProfileData {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String role;
        @AuraEnabled public Integer reputation;
        @AuraEnabled public Integer repositoryCount;
        @AuraEnabled public Integer contributionCount;
        @AuraEnabled public Integer badgeCount;
        @AuraEnabled public List<ContributorController.SkillLevel> skills;
        @AuraEnabled public List<ContributorController.BadgeItem> badges;
        @AuraEnabled public List<ContributorController.ProjectRole> projects;
        @AuraEnabled public List<ContributorController.RepoContribution> repositories;
    }
}
