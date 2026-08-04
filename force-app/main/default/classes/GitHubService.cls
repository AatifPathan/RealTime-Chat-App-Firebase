public with sharing class GitHubService {

    private static final String BASE_URL = 'https://api.github.com';

    private class RepoInfo{

        public String owner;
        public String repository;

    }

    private static RepoInfo parseGithubUrl(String githubUrl){

        RepoInfo info = new RepoInfo();

        if(String.isBlank(githubUrl)){
            return info;
        }

        Url url = new Url(githubUrl);

        String path = url.getPath();

        if(path.startsWith('/')){
            path = path.substring(1);
        }

        if(path.endsWith('.git')){
            path = path.substring(0, path.length() - 4);
        }

        List<String> parts = path.split('/');

        if(parts.size() >= 2){

            info.owner = parts[0];
            info.repository = parts[1];

        }

        return info;

    }

    public static GitHubRepositoryDTO getRepository(String githubUrl){

        RepoInfo info = parseGithubUrl(githubUrl);

        HttpRequest req = new HttpRequest();

        req.setEndpoint(
            BASE_URL +
            '/repos/' +
            EncodingUtil.urlEncode(info.owner,'UTF-8') +
            '/' +
            EncodingUtil.urlEncode(info.repository,'UTF-8')
        );

        req.setMethod('GET');
        req.setHeader('User-Agent','Salesforce');
        req.setHeader('Accept','application/vnd.github+json');

        Http http = new Http();

        HttpResponse res = http.send(req);

        if(res.getStatusCode() != 200){

            throw new CalloutException(
                'GitHub API Error: ' +
                res.getStatusCode() +
                ' - ' +
                res.getBody()
            );

        }

        return (GitHubRepositoryDTO)JSON.deserialize(
            res.getBody(),
            GitHubRepositoryDTO.class
        );

    }

    public static void syncRepository(Id repositoryId){

        Repository__c repo = [

            SELECT Id,
                   Github_URL__c

            FROM Repository__c

            WHERE Id = :repositoryId

            LIMIT 1

        ];

        GitHubRepositoryDTO githubRepo = getRepository(repo.Github_URL__c);

        repo.Description__c = githubRepo.description;
        repo.Stars__c = githubRepo.stargazers_count;
        repo.Forks__c = githubRepo.forks_count;
        repo.Open_Issues__c = githubRepo.open_issues_count;
        repo.Watchers__c = githubRepo.subscribers_count;
        repo.Primary_Language__c = githubRepo.language;
        repo.Visibility__c = githubRepo.visibility;
        repo.Last_Synced__c = System.now();

        if(githubRepo.license != null){
            repo.License__c = githubRepo.license.name;
        }

        if(githubRepo.topics != null){
            repo.Topics__c = String.join(githubRepo.topics, ', ');
        }

        if(!String.isBlank(githubRepo.created_at)){
            repo.Created_On_GitHub__c =
                Date.valueOf(githubRepo.created_at.substring(0,10));
        }

        update repo;

    }

}