/**
 * ProjectController
 * Backs `projects` and `projectDetail`. Project__c has no Progress__c,
 * Difficulty__c, or TechStack__c fields in the real schema — these are
 * computed live from the project's repositories/issues. See REAL_SCHEMA.md.
 */
public without sharing class ProjectController {

    private static final Set<String> VALID_NEW_STATUSES = new Set<String>{ 'Planning', 'Active', 'On Hold', 'Completed', 'Cancelled' };

    /**
     * Creating a Project requires being logged in — same rule as applying
     * to an issue.
     */
    @AuraEnabled
    public static Id createProject(String name, Id organizationId, String description, String status, Date endDate) {
        if (ContributorController.getCurrentContributorId() == null) {
            throw new AuraHandledException('Please log in to add a project.');
        }
        if (String.isBlank(name) || organizationId == null) {
            throw new AuraHandledException('Project name and organization are required.');
        }

        Project__c project = new Project__c(
            Name = name,
            Organization__c = organizationId,
            Description__c = description,
            Status__c = VALID_NEW_STATUSES.contains(status) ? status : 'Planning',
            End_Date__c = endDate
        );
        insert project;
        return project.Id;
    }

    private static final Set<String> VALID_STATUSES = new Set<String>{ 'Planning', 'Active', 'On Hold', 'Completed', 'Cancelled' };

    @AuraEnabled(cacheable=true)
    public static List<ProjectItem> getProjects(String searchTerm, String statusFilter) {
        String term = '%' + String.escapeSingleQuotes(searchTerm == null ? '' : searchTerm) + '%';

        String whereClause = 'WHERE Name LIKE :term';
        if (VALID_STATUSES.contains(statusFilter)) {
            whereClause += ' AND Status__c = :statusFilter';
        }

        String query = 'SELECT Id, Name, Organization__r.Name, Status__c, End_Date__c ' +
            'FROM Project__c ' + whereClause + ' ' +
            'ORDER BY CreatedDate DESC LIMIT 100';

        List<Project__c> projects = (List<Project__c>) Database.query(query);

        Map<Id, ProjectItem> itemById = new Map<Id, ProjectItem>();
        List<Id> orderedIds = new List<Id>();
        for (Project__c p : projects) {
            ProjectItem item = new ProjectItem();
            item.id = p.Id;
            item.name = p.Name;
            item.organizationName = p.Organization__r != null ? p.Organization__r.Name : null;
            item.status = p.Status__c;
            item.deadline = p.End_Date__c;
            item.progress = 0;
            itemById.put(p.Id, item);
            orderedIds.add(p.Id);
        }

        applyDerivedFields(itemById);

        List<ProjectItem> results = new List<ProjectItem>();
        for (Id pid : orderedIds) {
            results.add(itemById.get(pid));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static ProjectDetail getProjectDetail(Id projectId) {
        Project__c p = [
            SELECT Id, Name, Organization__r.Name, Description__c, Status__c,
                   End_Date__c, Project_Manager__c, Project_Manager__r.Name
            FROM Project__c
            WHERE Id = :projectId
            LIMIT 1
        ];

        Map<Id, ProjectItem> itemById = new Map<Id, ProjectItem>();
        ProjectItem item = new ProjectItem();
        item.id = p.Id;
        item.name = p.Name;
        item.organizationName = p.Organization__r != null ? p.Organization__r.Name : null;
        item.status = p.Status__c;
        item.deadline = p.End_Date__c;
        item.progress = 0;
        itemById.put(p.Id, item);
        applyDerivedFields(itemById);

        ProjectDetail detail = new ProjectDetail();
        detail.project = itemById.get(p.Id);
        detail.description = p.Description__c;
        detail.mentorName = p.Project_Manager__c != null ? p.Project_Manager__r.Name : null;

        detail.repositories = new List<RepoSummary>();
        List<Id> repoIds = new List<Id>();
        for (Repository__c r : [SELECT Id, Name, Primary_Language__c, Stars__c FROM Repository__c WHERE Project__c = :projectId]) {
            RepoSummary rs = new RepoSummary();
            rs.id = r.Id;
            rs.name = r.Name;
            rs.language = r.Primary_Language__c;
            rs.stars = r.Stars__c == null ? 0 : Integer.valueOf(r.Stars__c);
            detail.repositories.add(rs);
            repoIds.add(r.Id);
        }

        detail.openIssues = new List<IssueSummary>();
        detail.maintainers = new List<ContributorSummary>();
        Set<Id> maintainerIds = new Set<Id>();

        if (!repoIds.isEmpty()) {
            for (Issue__c i : [
                SELECT Id, Name, Difficulty__c
                FROM Issue__c
                WHERE Repository__c IN :repoIds AND Status__c != 'Closed'
                ORDER BY CreatedDate DESC
                LIMIT 8
            ]) {
                IssueSummary is = new IssueSummary();
                is.id = i.Id;
                is.title = i.Name;
                is.difficulty = i.Difficulty__c;
                detail.openIssues.add(is);
            }

            for (AggregateResult ar : [
                SELECT Contributor__c contributorId, COUNT(Id) cnt
                FROM Contribution__c
                WHERE Issue__r.Repository__c IN :repoIds AND Contributor__c != null
                GROUP BY Contributor__c
                ORDER BY COUNT(Id) DESC
                LIMIT 6
            ]) {
                maintainerIds.add((Id) ar.get('contributorId'));
            }
        }

        if (p.Project_Manager__c != null) {
            ContributorSummary lead = new ContributorSummary();
            lead.id = p.Project_Manager__c;
            lead.name = p.Project_Manager__r.Name;
            lead.role = 'Project Lead (Mentor)';
            detail.maintainers.add(lead);
        }
        if (!maintainerIds.isEmpty()) {
            for (Contributor__c c : [SELECT Id, Name FROM Contributor__c WHERE Id IN :maintainerIds LIMIT 8]) {
                ContributorSummary cs = new ContributorSummary();
                cs.id = c.Id;
                cs.name = c.Name;
                cs.role = 'Contributor';
                detail.maintainers.add(cs);
            }
        }

        detail.timeline = new List<TimelineItem>();
        if (!repoIds.isEmpty()) {
            for (Contribution__c con : [
                SELECT Id, Review_Status__c, Contributor__r.Name, CreatedDate
                FROM Contribution__c
                WHERE Issue__r.Repository__c IN :repoIds
                ORDER BY CreatedDate DESC
                LIMIT 6
            ]) {
                TimelineItem ti = new TimelineItem();
                ti.id = con.Id;
                ti.text = (con.Contributor__r != null ? con.Contributor__r.Name : 'Someone') + ' \u2014 ' + con.Review_Status__c;
                ti.timestamp = con.CreatedDate;
                detail.timeline.add(ti);
            }
        }

        return detail;
    }

    /**
     * Fills in progress % (closed vs total issues), difficulty (most common
     * repo difficulty), and stack (distinct repo languages) for a set of
     * projects — none of these exist as direct fields on Project__c.
     */
    private static void applyDerivedFields(Map<Id, ProjectItem> itemById) {
        if (itemById.isEmpty()) {
            return;
        }
        Set<Id> projectIds = itemById.keySet();

        Map<Id, Map<String, Integer>> difficultyCountsByProject = new Map<Id, Map<String, Integer>>();
        Map<Id, Set<String>> languagesByProject = new Map<Id, Set<String>>();
        for (Repository__c r : [
            SELECT Id, Project__c, Difficulty_Level__c, Primary_Language__c
            FROM Repository__c
            WHERE Project__c IN :projectIds
        ]) {
            if (String.isNotBlank(r.Difficulty_Level__c)) {
                if (!difficultyCountsByProject.containsKey(r.Project__c)) {
                    difficultyCountsByProject.put(r.Project__c, new Map<String, Integer>());
                }
                Map<String, Integer> counts = difficultyCountsByProject.get(r.Project__c);
                counts.put(r.Difficulty_Level__c, (counts.containsKey(r.Difficulty_Level__c) ? counts.get(r.Difficulty_Level__c) : 0) + 1);
            }
            if (String.isNotBlank(r.Primary_Language__c)) {
                if (!languagesByProject.containsKey(r.Project__c)) {
                    languagesByProject.put(r.Project__c, new Set<String>());
                }
                languagesByProject.get(r.Project__c).add(r.Primary_Language__c);
            }
        }

        for (Id pid : projectIds) {
            ProjectItem item = itemById.get(pid);
            item.stack = languagesByProject.containsKey(pid) ? new List<String>(languagesByProject.get(pid)) : new List<String>();

            String topDifficulty = null;
            Integer topCount = 0;
            if (difficultyCountsByProject.containsKey(pid)) {
                for (String diff : difficultyCountsByProject.get(pid).keySet()) {
                    Integer cnt = difficultyCountsByProject.get(pid).get(diff);
                    if (cnt > topCount) {
                        topCount = cnt;
                        topDifficulty = diff;
                    }
                }
            }
            item.difficulty = topDifficulty;
        }

        Map<Id, DashboardController.ProjectItem> progressMap = new Map<Id, DashboardController.ProjectItem>();
        for (Id pid : projectIds) {
            DashboardController.ProjectItem p = new DashboardController.ProjectItem();
            p.id = pid;
            p.progress = 0;
            progressMap.put(pid, p);
        }
        DashboardController.applyProjectProgress(progressMap);
        for (Id pid : projectIds) {
            itemById.get(pid).progress = progressMap.get(pid).progress;
        }
    }

    // ---------- DTOs ----------

    public class ProjectItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String organizationName;
        @AuraEnabled public String status;
        @AuraEnabled public String difficulty;
        @AuraEnabled public Integer progress;
        @AuraEnabled public List<String> stack;
        @AuraEnabled public Date deadline;
    }

    public class ProjectDetail {
        @AuraEnabled public ProjectItem project;
        @AuraEnabled public String description;
        @AuraEnabled public String mentorName;
        @AuraEnabled public List<RepoSummary> repositories;
        @AuraEnabled public List<IssueSummary> openIssues;
        @AuraEnabled public List<ContributorSummary> maintainers;
        @AuraEnabled public List<TimelineItem> timeline;
    }

    public class RepoSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String language;
        @AuraEnabled public Integer stars;
    }

    public class IssueSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String difficulty;
    }

    public class ContributorSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
    }

    public class TimelineItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String text;
        @AuraEnabled public Datetime timestamp;
    }
}
