import { LightningElement, wire } from 'lwc';
import isGuest from '@salesforce/user/isGuest';
import getNotifications from '@salesforce/apex/NotificationController.getNotifications';

const SECTION_BY_PAGE = {
    dashboard: 'dashboard',
    organizations: 'organizations',
    organizationDetail: 'organizations',
    repositories: 'repositories',
    repositoryDetail: 'repositories',
    projects: 'projects',
    projectDetail: 'projects',
    contributors: 'contributors',
    contributorProfile: 'contributors',
    issues: 'issues',
    issueDetail: 'issues',
    applications: 'applications',
    applicationReview: 'applications',
    skills: 'skills',
    badges: 'badges',
    mentorDashboard: 'mentorDashboard',
    profile: 'profile',
    settings: 'settings',
    notifications: 'notifications'
};

const PAGE_TITLES = {
    dashboard: 'Dashboard',
    organizations: 'Organizations',
    organizationDetail: 'Organization',
    repositories: 'Repositories',
    repositoryDetail: 'Repository',
    projects: 'Projects',
    projectDetail: 'Project',
    contributors: 'Contributors',
    contributorProfile: 'Contributor',
    issues: 'Issues',
    issueDetail: 'Issue',
    applications: 'Applications',
    applicationReview: 'Application Review',
    skills: 'Skills',
    badges: 'Badges',
    mentorDashboard: 'Mentor Dashboard',
    profile: 'Profile',
    settings: 'Settings',
    notifications: 'Notifications'
};

const MAIN_NAV = [
    { page: 'dashboard', label: 'Dashboard', icon: '⌘' },
    { page: 'repositories', label: 'Repositories', icon: '◧' },
    { page: 'organizations', label: 'Organizations', icon: '⌂' },
    { page: 'projects', label: 'Projects', icon: '◍' },
    { page: 'issues', label: 'Issues', icon: '✎' },
    { page: 'applications', label: 'Applications', icon: '▤' }
];

const COMMUNITY_NAV = [
    { page: 'contributors', label: 'Contributors', icon: '◎' },
    { page: 'skills', label: 'Skills', icon: '★' },
    { page: 'badges', label: 'Badges', icon: '◆' },
    { page: 'mentorDashboard', label: 'Mentor Dashboard', icon: '◈' }
];

const FOOTER_NAV = [
    { page: 'profile', label: 'Profile', icon: '◍' },
    { page: 'settings', label: 'Settings', icon: '⚙' }
];

export default class OpenCoreApp extends LightningElement {
    currentPage = 'dashboard';
    currentRecordId = null;
    hasUnreadNotifications = false;

    get isGuestUser() {
        return isGuest;
    }

    @wire(getNotifications)
    wiredNotifications({ data }) {
        if (isGuest) {
            return;
        }
        if (data) {
            this.hasUnreadNotifications = data.some((n) => n.unread);
        }
    }

    connectedCallback() {
        this.template.addEventListener('navigate', this.handleNavigate.bind(this));
    }

    handleNavigate(event) {
        const { page, recordId } = event.detail || {};
        if (!page) {
            return;
        }
        this.currentPage = page;
        this.currentRecordId = recordId || null;
        this.scrollContentToTop();
    }

    handleNavClick(event) {
        const page = event.currentTarget.dataset.page;
        this.currentPage = page;
        this.currentRecordId = null;
        this.scrollContentToTop();
    }

    scrollContentToTop() {
        const content = this.template.querySelector('.oc-content');
        if (content) {
            content.scrollTop = 0;
        }
    }

    get pageTitle() {
        return PAGE_TITLES[this.currentPage] || 'OpenCore';
    }

    get activeSection() {
        return SECTION_BY_PAGE[this.currentPage] || 'dashboard';
    }

    buildNavItems(items) {
        return items.map((item) => ({
            ...item,
            navClass: this.activeSection === item.page ? 'oc-nav-item is-active' : 'oc-nav-item'
        }));
    }

    get mainNavItems() { return this.buildNavItems(MAIN_NAV); }
    get communityNavItems() { return this.buildNavItems(COMMUNITY_NAV); }
    get footerNavItems() { return this.buildNavItems(FOOTER_NAV); }

    get isDashboard() { return this.currentPage === 'dashboard'; }
    get isOrganizations() { return this.currentPage === 'organizations'; }
    get isOrganizationDetail() { return this.currentPage === 'organizationDetail'; }
    get isRepositories() { return this.currentPage === 'repositories'; }
    get isRepositoryDetail() { return this.currentPage === 'repositoryDetail'; }
    get isProjects() { return this.currentPage === 'projects'; }
    get isProjectDetail() { return this.currentPage === 'projectDetail'; }
    get isContributors() { return this.currentPage === 'contributors'; }
    get isContributorProfile() { return this.currentPage === 'contributorProfile'; }
    get isIssues() { return this.currentPage === 'issues'; }
    get isIssueDetail() { return this.currentPage === 'issueDetail'; }
    get isApplications() { return this.currentPage === 'applications'; }
    get isApplicationReview() { return this.currentPage === 'applicationReview'; }
    get isBadges() { return this.currentPage === 'badges'; }
    get isSkills() { return this.currentPage === 'skills'; }
    get isMentorDashboard() { return this.currentPage === 'mentorDashboard'; }
    get isProfile() { return this.currentPage === 'profile'; }
    get isSettings() { return this.currentPage === 'settings'; }
    get isNotifications() { return this.currentPage === 'notifications'; }
}
