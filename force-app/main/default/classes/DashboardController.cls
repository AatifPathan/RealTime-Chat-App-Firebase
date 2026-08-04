public without sharing class DashboardController {

    @AuraEnabled(cacheable=true)
    public static Integer getRepositoryCount() {
        return [SELECT COUNT() FROM Repository__c];
    }

    @AuraEnabled(cacheable=true)
    public static Integer getOrganizationCount() {
        return [SELECT COUNT() FROM Organization__c];
    }

    @AuraEnabled(cacheable=true)
    public static Integer getContributorCount() {
        return [SELECT COUNT() FROM Contributor__c];
    }

    @AuraEnabled(cacheable=true)
    public static Integer getProjectCount() {
        return [SELECT COUNT() FROM Project__c];
    }

    /**
     * Added for the openCoreApp SPA's dashboard page. Does not replace the
     * four counter methods above (kept for any other existing callers) —
     * this aggregates everything the dashboard needs into one round trip.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        DashboardData data = new DashboardData();

        data.kpis = new KpiData();
        data.kpis.totalOrganizations = getOrganizationCount();
        data.kpis.totalRepositories = getRepositoryCount();
        data.kpis.totalProjects = getProjectCount();
        data.kpis.totalContributors = getContributorCount();
        data.kpis.openIssues = [SELECT COUNT() FROM Issue__c WHERE Status__c != 'Closed'];
        data.kpis.pendingApplications = [SELECT COUNT() FROM Application__c WHERE Status__c = 'Pending'];

        data.recentRepositories = new List<RepoItem>();
        for (Repository__c r : [
            SELECT Id, Name, Primary_Language__c, Stars__c, Difficulty_Level__c
            FROM Repository__c
            ORDER BY CreatedDate DESC
            LIMIT 5
        ]) {
            RepoItem item = new RepoItem();
            item.id = r.Id;
            item.name = r.Name;
            item.language = r.Primary_Language__c;
            item.stars = r.Stars__c == null ? 0 : Integer.valueOf(r.Stars__c);
            item.difficulty = r.Difficulty_Level__c;
            data.recentRepositories.add(item);
        }

        data.recentContributors = new List<ContributorItem>();
        for (Contributor__c c : [
            SELECT Id, Name, Experience_Level__c, Current_Rank__c, Reputation_Score__c
            FROM Contributor__c
            ORDER BY CreatedDate DESC
            LIMIT 5
        ]) {
            ContributorItem item = new ContributorItem();
            item.id = c.Id;
            item.name = c.Name;
            item.role = (c.Experience_Level__c == null ? '' : c.Experience_Level__c) +
                (c.Current_Rank__c == null ? '' : ' \u00B7 ' + c.Current_Rank__c);
            item.reputation = c.Reputation_Score__c == null ? 0 : Integer.valueOf(c.Reputation_Score__c);
            data.recentContributors.add(item);
        }

        List<Id> recentProjectIds = new List<Id>();
        Map<Id, ProjectItem> projectItemById = new Map<Id, ProjectItem>();
        for (Project__c p : [
            SELECT Id, Name
            FROM Project__c
            ORDER BY CreatedDate DESC
            LIMIT 5
        ]) {
            ProjectItem item = new ProjectItem();
            item.id = p.Id;
            item.name = p.Name;
            item.progress = 0;
            projectItemById.put(p.Id, item);
            recentProjectIds.add(p.Id);
        }
        applyProjectProgress(projectItemById);
        data.recentProjects = new List<ProjectItem>();
        for (Id pid : recentProjectIds) {
            data.recentProjects.add(projectItemById.get(pid));
        }

        data.recentActivity = new List<ActivityItem>();
        for (Contribution__c con : [
            SELECT Id, Review_Status__c, Contributor__r.Name, Issue__r.Name, Submission_Date__c, CreatedDate
            FROM Contribution__c
            ORDER BY CreatedDate DESC
            LIMIT 6
        ]) {
            ActivityItem item = new ActivityItem();
            item.id = con.Id;
            item.text = (con.Contributor__r != null ? con.Contributor__r.Name : 'Someone') +
                ' \u2014 ' + con.Review_Status__c +
                (con.Issue__r != null ? ' on "' + con.Issue__r.Name + '"' : '');
            item.timestamp = con.CreatedDate;
            data.recentActivity.add(item);
        }

        data.contributionsByDay = getContributionsByDay();

        return data;
    }

    /**
     * Buckets Contribution__c records by day-of-week for the last 7 days.
     * Real data source (replaces the fictional activity log used before).
     */
    private static List<ChartPoint> getContributionsByDay() {
        Map<String, Integer> countsByDay = new Map<String, Integer>{
            'Mon' => 0, 'Tue' => 0, 'Wed' => 0, 'Thu' => 0, 'Fri' => 0, 'Sat' => 0, 'Sun' => 0
        };
        List<String> orderedLabels = new List<String>{ 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' };

        for (Contribution__c con : [
            SELECT Submission_Date__c
            FROM Contribution__c
            WHERE Submission_Date__c = LAST_N_DAYS:7 AND Submission_Date__c != null
        ]) {
            Datetime dt = Datetime.newInstance(con.Submission_Date__c.year(), con.Submission_Date__c.month(), con.Submission_Date__c.day());
            String label = dt.format('EEE');
            if (countsByDay.containsKey(label)) {
                countsByDay.put(label, countsByDay.get(label) + 1);
            }
        }

        Integer maxCount = 1;
        for (String label : orderedLabels) {
            maxCount = Math.max(maxCount, countsByDay.get(label));
        }

        List<ChartPoint> points = new List<ChartPoint>();
        for (String label : orderedLabels) {
            ChartPoint point = new ChartPoint();
            point.label = label;
            point.value = countsByDay.get(label);
            point.percentOfMax = (Integer) Math.round((countsByDay.get(label) * 100.0) / maxCount);
            points.add(point);
        }
        return points;
    }

    /**
     * Computes real "progress %" for a set of projects as closed vs. total
     * Issue__c across each project's repositories. Shared by DashboardController
     * and ProjectController — Project__c has no Progress__c field.
     */
    public static void applyProjectProgress(Map<Id, ProjectItem> projectItemById) {
        if (projectItemById.isEmpty()) {
            return;
        }
        Map<Id, Integer> totalByProject = new Map<Id, Integer>();
        Map<Id, Integer> closedByProject = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Repository__r.Project__c pid, Status__c st, COUNT(Id) cnt
            FROM Issue__c
            WHERE Repository__r.Project__c IN :projectItemById.keySet()
            GROUP BY Repository__r.Project__c, Status__c
        ]) {
            Id pid = (Id) ar.get('pid');
            Integer cnt = (Integer) ar.get('cnt');
            totalByProject.put(pid, (totalByProject.containsKey(pid) ? totalByProject.get(pid) : 0) + cnt);
            if ((String) ar.get('st') == 'Closed') {
                closedByProject.put(pid, (closedByProject.containsKey(pid) ? closedByProject.get(pid) : 0) + cnt);
            }
        }
        for (Id pid : projectItemById.keySet()) {
            Integer total = totalByProject.containsKey(pid) ? totalByProject.get(pid) : 0;
            Integer closed = closedByProject.containsKey(pid) ? closedByProject.get(pid) : 0;
            projectItemById.get(pid).progress = total == 0 ? 0 : (Integer) Math.round((closed * 100.0) / total);
        }
    }

    // ---------- DTOs ----------

    public class DashboardData {
        @AuraEnabled public KpiData kpis;
        @AuraEnabled public List<RepoItem> recentRepositories;
        @AuraEnabled public List<ContributorItem> recentContributors;
        @AuraEnabled public List<ProjectItem> recentProjects;
        @AuraEnabled public List<ActivityItem> recentActivity;
        @AuraEnabled public List<ChartPoint> contributionsByDay;
    }

    public class KpiData {
        @AuraEnabled public Integer totalOrganizations;
        @AuraEnabled public Integer totalRepositories;
        @AuraEnabled public Integer totalProjects;
        @AuraEnabled public Integer totalContributors;
        @AuraEnabled public Integer openIssues;
        @AuraEnabled public Integer pendingApplications;
    }

    public class RepoItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String language;
        @AuraEnabled public Integer stars;
        @AuraEnabled public String difficulty;
    }

    public class ContributorItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
        @AuraEnabled public Integer reputation;
    }

    public class ProjectItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer progress;
    }

    public class ActivityItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String text;
        @AuraEnabled public Datetime timestamp;
    }

    public class ChartPoint {
        @AuraEnabled public String label;
        @AuraEnabled public Integer value;
        @AuraEnabled public Integer percentOfMax;
    }
}