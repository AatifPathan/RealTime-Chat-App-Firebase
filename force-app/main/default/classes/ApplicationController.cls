/**
 * ApplicationController
 * Backs `applications` and `applicationReview`. Application__c has real
 * validation rules this controller must satisfy:
 *  - Approved_Application_Requires_Reviewer: Reviewer__c (a Mentor__c) must
 *    be set before Status__c can be 'Approved'.
 *  - Rejected_Application_Requires_Comments: Review_Comments__c must be
 *    non-blank before Status__c can be 'Rejected'.
 *  - Review_Date_After_Applied_Date: Reviewed_On__c can't precede Applied_On__c.
 * updateApplicationStatus() resolves the running user's Mentor__c (via
 * MentorController.getCurrentMentorId()) and sets it as Reviewer__c so the
 * approve/reject actions succeed against these rules.
 */
public with sharing class ApplicationController {

    private static final Set<String> VALID_STATUSES = new Set<String>{ 'Pending', 'Approved', 'Rejected', 'Withdrawn' };

    @AuraEnabled(cacheable=true)
    public static List<ApplicationItem> getApplications(String searchTerm, String statusFilter) {
        String term = '%' + String.escapeSingleQuotes(searchTerm == null ? '' : searchTerm) + '%';

        String whereClause = 'WHERE Contributor__r.Name LIKE :term';
        if (VALID_STATUSES.contains(statusFilter)) {
            whereClause += ' AND Status__c = :statusFilter';
        }

        String query = 'SELECT Id, Contributor__r.Name, Issue__r.Name, Issue__r.Repository__r.Name, ' +
            'Status__c, Applied_On__c ' +
            'FROM Application__c ' + whereClause + ' ' +
            'ORDER BY Applied_On__c DESC LIMIT 100';

        List<ApplicationItem> results = new List<ApplicationItem>();
        for (Application__c a : (List<Application__c>) Database.query(query)) {
            results.add(toApplicationItem(a));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static ApplicationReviewData getApplicationReview(Id applicationId) {
        Application__c a = [
            SELECT Id, Status__c, Applied_On__c,
                   Issue__r.Name, Issue__r.Repository__r.Name,
                   Contributor__r.Id, Contributor__r.Name, Contributor__r.Experience_Level__c,
                   Contributor__r.Current_Rank__c, Contributor__r.Bio__c,
                   Contributor__r.Reputation_Score__c, Contributor__r.GitHub_Username__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        ApplicationReviewData data = new ApplicationReviewData();
        data.application = toApplicationItem(a);
        data.applicantId = a.Contributor__r.Id;
        data.applicantName = a.Contributor__r.Name;
        data.applicantTitle = (a.Contributor__r.Experience_Level__c == null ? '' : a.Contributor__r.Experience_Level__c) +
            (a.Contributor__r.Current_Rank__c == null ? '' : ' \u00B7 ' + a.Contributor__r.Current_Rank__c);
        data.applicantBio = a.Contributor__r.Bio__c;
        data.applicantReputation = a.Contributor__r.Reputation_Score__c == null ? 0 : Integer.valueOf(a.Contributor__r.Reputation_Score__c);
        data.applicantGithub = a.Contributor__r.GitHub_Username__c;

        data.applicantSkills = new List<String>();
        for (Contributor_Skill__c cs : [
            SELECT Skill__r.Name
            FROM Contributor_Skill__c
            WHERE Contributor__c = :a.Contributor__r.Id
            ORDER BY Primary_Skill__c DESC
            LIMIT 6
        ]) {
            data.applicantSkills.add(cs.Skill__r.Name);
        }

        return data;
    }

    @AuraEnabled
    public static void updateApplicationStatus(Id applicationId, String newStatus, String reviewComments) {
        if (newStatus != 'Approved' && newStatus != 'Rejected') {
            throw new AuraHandledException('Invalid status: ' + newStatus);
        }

        Id mentorId = MentorController.getCurrentMentorId();
        if (mentorId == null) {
            throw new AuraHandledException('No Mentor record is linked to your Salesforce user (expected: Mentor__c owned by you). A Reviewer is required to approve or reject applications.');
        }

        Application__c application = new Application__c(
            Id = applicationId,
            Status__c = newStatus,
            Reviewer__c = mentorId,
            Reviewed_On__c = Date.today(),
            Review_Comments__c = reviewComments
        );
        update application;
    }

    private static ApplicationItem toApplicationItem(Application__c a) {
        ApplicationItem item = new ApplicationItem();
        item.id = a.Id;
        item.applicantName = a.Contributor__r != null ? a.Contributor__r.Name : null;
        item.issueTitle = a.Issue__r != null ? a.Issue__r.Name : null;
        item.repositoryName = a.Issue__r != null && a.Issue__r.Repository__r != null ? a.Issue__r.Repository__r.Name : null;
        item.status = a.Status__c;
        item.appliedDate = a.Applied_On__c;
        return item;
    }

    // ---------- DTOs ----------

    public class ApplicationItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String applicantName;
        @AuraEnabled public String issueTitle;
        @AuraEnabled public String repositoryName;
        @AuraEnabled public String status;
        @AuraEnabled public Date appliedDate;
    }

    public class ApplicationReviewData {
        @AuraEnabled public ApplicationItem application;
        @AuraEnabled public Id applicantId;
        @AuraEnabled public String applicantName;
        @AuraEnabled public String applicantTitle;
        @AuraEnabled public String applicantBio;
        @AuraEnabled public Integer applicantReputation;
        @AuraEnabled public String applicantGithub;
        @AuraEnabled public List<String> applicantSkills;
    }
}
