public class GitHubRepositoryDTO {

    public String description;
    public Integer stargazers_count;
    public Integer forks_count;
    public Integer open_issues_count;
    public Integer subscribers_count;
    public String language;
    public String visibility;
    public String created_at;
    public List<String> topics;
    public License license;

    public class License{

        public String name;

    }

}