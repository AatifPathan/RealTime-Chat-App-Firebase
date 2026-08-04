@RestResource(urlMapping='/dashboard/*')
global with sharing class DashboardAPI {

    @HttpGet
    global static Map<String,Integer> getDashboard() {

        Map<String,Integer> stats = new Map<String,Integer>();

        stats.put('Repositories',
            DashboardService.totalRepositories());

        stats.put('Contributors',
            DashboardService.totalContributors());

        return stats;

    }

}