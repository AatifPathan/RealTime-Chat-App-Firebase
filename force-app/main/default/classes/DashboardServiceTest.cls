@isTest
private class DashboardServiceTest {

    @isTest
    static void testDashboard(){

        Integer repositories =
            DashboardService.totalRepositories();

        Integer contributors =
            DashboardService.totalContributors();

        System.assertNotEquals(
            null,
            repositories
        );

        System.assertNotEquals(
            null,
            contributors
        );

    }

}