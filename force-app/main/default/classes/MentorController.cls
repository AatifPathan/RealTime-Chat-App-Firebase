/**
 * MentorController
 * Backs `mentorDashboard`, and exposes getCurrentMentorId() used by
 * ApplicationController when approving/rejecting. Mentor__c is a real,
 * separate object here (not a role on Contributor__c) — see REAL_SCHEMA.md.
 */
public with sharing class MentorController {

    /**
     * Resolves the Mentor__c record for the running user via OwnerId, same
     * pattern as ContributorController.getCurrentContributorId(). A person
     * could plausibly own both a Contributor__c and a Mentor__c record.
     */
    public static Id getCurrentMentorId() {
        List<Mentor__c> matches = [
            SELECT Id FROM Mentor__c WHERE OwnerId = :UserInfo.getUserId() LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0].Id;
    }

    @AuraEnabled(cacheable=true)
    public static MentorDashboardData getMentorDashboard() {
        Id mentorId = getCurrentMentorId();
        if (mentorId == null) {
            throw new AuraHandledException('No Mentor record is linked to your Salesforce user. Ask an admin to check record ownership.');
        }

        MentorDashboardData data = new MentorDashboardData();

        Set<Id> mentoredProjectIds = new Set<Id>();
        for (Project__c p : [SELECT Id FROM Project__c WHERE Project_Manager__c = :mentorId]) {
            mentoredProjectIds.add(p.Id);
        }
        Set<Id> mentoredOrgIds = new Set<Id>();
        for (Organization__c o : [SELECT Id FROM Organization__c WHERE Primary_Mentor__c = :mentorId]) {
            mentoredOrgIds.add(o.Id);
        }

        Set<Id> mentoredRepoIds = new Set<Id>();
        if (!mentoredOrgIds.isEmpty() || !mentoredProjectIds.isEmpty()) {
            for (Repository__c r : [
                SELECT Id FROM Repository__c
                WHERE Organization__c IN :mentoredOrgIds OR Project__c IN :mentoredProjectIds
            ]) {
                mentoredRepoIds.add(r.Id);
            }
        }

        data.stats = new MentorStats();
        data.stats.pendingApplications = [
            SELECT COUNT() FROM Application__c
            WHERE Status__c = 'Pending' AND Issue__r.Repository__c IN :mentoredRepoIds
        ];
        data.stats.activeProjects = mentoredProjectIds.size();
        data.stats.repositoriesMentored = mentoredRepoIds.size();
        data.stats.reviewsThisMonth = [
            SELECT COUNT() FROM Application__c
            WHERE Reviewer__c = :mentorId AND Reviewed_On__c = THIS_MONTH
        ];

        data.pendingApplications = new List<ApplicationController.ApplicationItem>();
        for (Application__c a : [
            SELECT Id, Contributor__r.Name, Issue__r.Name, Issue__r.Repository__r.Name, Status__c, Applied_On__c
            FROM Application__c
            WHERE Status__c = 'Pending' AND Issue__r.Repository__c IN :mentoredRepoIds
            ORDER BY Applied_On__c DESC
            LIMIT 6
        ]) {
            ApplicationController.ApplicationItem item = new ApplicationController.ApplicationItem();
            item.id = a.Id;
            item.applicantName = a.Contributor__r.Name;
            item.issueTitle = a.Issue__r != null ? a.Issue__r.Name : null;
            item.repositoryName = a.Issue__r != null && a.Issue__r.Repository__r != null ? a.Issue__r.Repository__r.Name : null;
            item.status = a.Status__c;
            item.appliedDate = a.Applied_On__c;
            data.pendingApplications.add(item);
        }

        data.projects = new List<ProjectController.ProjectItem>();
        if (!mentoredProjectIds.isEmpty()) {
            Map<Id, ProjectController.ProjectItem> itemById = new Map<Id, ProjectController.ProjectItem>();
            List<Id> orderedIds = new List<Id>();
            for (Project__c p : [
                SELECT Id, Name, Organization__r.Name, Status__c, End_Date__c
                FROM Project__c
                WHERE Id IN :mentoredProjectIds
                LIMIT 6
            ]) {
                ProjectController.ProjectItem item = new ProjectController.ProjectItem();
                item.id = p.Id;
                item.name = p.Name;
                item.organizationName = p.Organization__r != null ? p.Organization__r.Name : null;
                item.status = p.Status__c;
                item.deadline = p.End_Date__c;
                item.progress = 0;
                itemById.put(p.Id, item);
                orderedIds.add(p.Id);
            }
            Map<Id, DashboardController.ProjectItem> progressMap = new Map<Id, DashboardController.ProjectItem>();
            for (Id pid : orderedIds) {
                DashboardController.ProjectItem probe = new DashboardController.ProjectItem();
                probe.id = pid;
                probe.progress = 0;
                progressMap.put(pid, probe);
            }
            DashboardController.applyProjectProgress(progressMap);
            for (Id pid : orderedIds) {
                itemById.get(pid).progress = progressMap.get(pid).progress;
            }
            for (Id pid : orderedIds) {
                data.projects.add(itemById.get(pid));
            }
        }

        data.repositories = new List<RepositoryController.RepoItem>();
        if (!mentoredRepoIds.isEmpty()) {
            for (Repository__c r : [
                SELECT Id, Name, Organization__r.Name, Primary_Language__c, Stars__c, Forks__c,
                       Open_Issues__c, Difficulty_Level__c, Status__c
                FROM Repository__c
                WHERE Id IN :mentoredRepoIds
                ORDER BY Open_Issues__c DESC NULLS LAST
                LIMIT 6
            ]) {
                RepositoryController.RepoItem item = new RepositoryController.RepoItem();
                item.id = r.Id;
                item.name = r.Name;
                item.organizationName = r.Organization__r != null ? r.Organization__r.Name : null;
                item.language = r.Primary_Language__c;
                item.stars = r.Stars__c == null ? 0 : Integer.valueOf(r.Stars__c);
                item.forks = r.Forks__c == null ? 0 : Integer.valueOf(r.Forks__c);
                item.openIssuesCount = r.Open_Issues__c == null ? 0 : Integer.valueOf(r.Open_Issues__c);
                item.difficulty = r.Difficulty_Level__c;
                item.status = r.Status__c;
                data.repositories.add(item);
            }
        }

        data.recentReviews = new List<ReviewItem>();
        for (Application__c a : [
            SELECT Id, Status__c, Contributor__r.Name, Issue__r.Repository__r.Name, Reviewed_On__c, LastModifiedDate
            FROM Application__c
            WHERE Reviewer__c = :mentorId AND Status__c != 'Pending'
            ORDER BY LastModifiedDate DESC
            LIMIT 6
        ]) {
            ReviewItem item = new ReviewItem();
            item.id = a.Id;
            item.text = (a.Status__c == 'Approved' ? 'Approved ' : a.Status__c + ' ') + a.Contributor__r.Name +
                (a.Issue__r != null && a.Issue__r.Repository__r != null ? ' for ' + a.Issue__r.Repository__r.Name : '');
            item.timestamp = a.LastModifiedDate;
            data.recentReviews.add(item);
        }

        return data;
    }

    // ---------- DTOs ----------

    public class MentorDashboardData {
        @AuraEnabled public MentorStats stats;
        @AuraEnabled public List<ApplicationController.ApplicationItem> pendingApplications;
        @AuraEnabled public List<ProjectController.ProjectItem> projects;
        @AuraEnabled public List<RepositoryController.RepoItem> repositories;
        @AuraEnabled public List<ReviewItem> recentReviews;
    }

    public class MentorStats {
        @AuraEnabled public Integer pendingApplications;
        @AuraEnabled public Integer activeProjects;
        @AuraEnabled public Integer repositoriesMentored;
        @AuraEnabled public Integer reviewsThisMonth;
    }

    public class ReviewItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String text;
        @AuraEnabled public Datetime timestamp;
    }
}
