@RestResource(urlMapping='/projects/*')
global with sharing class ProjectAPI {

    @HttpGet
    global static List<Project__c> getProjects() {

        return ProjectService.getProjects();

    }

}