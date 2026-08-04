import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDashboardData from '@salesforce/apex/DashboardController.getDashboardData';

export default class Dashboard extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';

    kpis = [];
    barChart = [];
    activity = [];
    recentRepos = [];
    recentContributors = [];
    recentProjects = [];
    kpiOpenIssues = 0;
    kpiPendingApplications = 0;

    wiredResult;

    @wire(getDashboardData)
    wiredDashboard(result) {
        this.wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;

        if (data) {
            this.hasError = false;
            this.applyData(data);
        } else if (error) {
            this.hasError = true;
            this.errorMessage = this.reduceError(error);
            this.showErrorToast();
        }
    }

    applyData(data) {
        const k = data.kpis || {};
        this.kpis = [
            { label: 'Repositories', value: k.totalRepositories ?? 0, icon: '⌘' },
            { label: 'Organizations', value: k.totalOrganizations ?? 0, icon: '⌂' },
            { label: 'Projects', value: k.totalProjects ?? 0, icon: '◧' },
            { label: 'Contributors', value: k.totalContributors ?? 0, icon: '◍' },
            { label: 'Open Issues', value: k.openIssues ?? 0, icon: '◎' },
            { label: 'Pending Applications', value: k.pendingApplications ?? 0, icon: '✎' }
        ];
        this.kpiOpenIssues = k.openIssues ?? 0;
        this.kpiPendingApplications = k.pendingApplications ?? 0;

        this.barChart = (data.contributionsByDay || []).map((point) => ({
            label: point.label,
            style: `height:${Math.max(4, point.percentOfMax)}%`
        }));

        this.activity = (data.recentActivity || []).map((a) => ({
            id: a.id,
            text: a.text,
            meta: this.formatRelativeTime(a.timestamp)
        }));

        this.recentRepos = (data.recentRepositories || []).map((r) => ({
            id: r.id,
            name: r.name,
            language: r.language,
            stars: r.stars,
            difficulty: r.difficulty,
            initials: this.initials(r.name),
            badgeClass: this.difficultyBadgeClass(r.difficulty)
        }));

        this.recentContributors = (data.recentContributors || []).map((c) => ({
            id: c.id,
            name: c.name,
            role: c.role,
            reputation: c.reputation,
            initials: this.initials(c.name)
        }));

        this.recentProjects = (data.recentProjects || []).map((p) => ({
            id: p.id,
            name: p.name,
            progress: p.progress,
            style: `width:${p.progress}%`
        }));
    }

    get showContent() {
        return !this.isLoading && !this.hasError;
    }

    get hasBarChart() {
        return this.barChart.some((b) => parseInt(b.style.replace(/\D/g, ''), 10) > 4);
    }
    get hasActivity() { return this.activity.length > 0; }
    get hasRepos() { return this.recentRepos.length > 0; }
    get hasContributors() { return this.recentContributors.length > 0; }
    get hasProjects() { return this.recentProjects.length > 0; }

    initials(name) {
        return (name || '')
            .split(/[\s-]+/)
            .map((p) => p[0])
            .join('')
            .slice(0, 2)
            .toUpperCase();
    }

    difficultyBadgeClass(difficulty) {
        const map = {
            Beginner: 'oc-badge oc-badge-green',
            Intermediate: 'oc-badge oc-badge-amber',
            Advanced: 'oc-badge oc-badge-red'
        };
        return map[difficulty] || 'oc-badge';
    }

    formatRelativeTime(isoString) {
        if (!isoString) return '';
        const then = new Date(isoString).getTime();
        const diffMs = Date.now() - then;
        const minutes = Math.floor(diffMs / 60000);
        if (minutes < 1) return 'just now';
        if (minutes < 60) return `${minutes} minute${minutes === 1 ? '' : 's'} ago`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours} hour${hours === 1 ? '' : 's'} ago`;
        const days = Math.floor(hours / 24);
        return `${days} day${days === 1 ? '' : 's'} ago`;
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred while loading the dashboard.';
    }

    showErrorToast() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Couldn\u2019t load dashboard',
            message: this.errorMessage,
            variant: 'error'
        }));
    }

    handleRetry() {
        this.isLoading = true;
        this.hasError = false;
        refreshApex(this.wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    handleNewProject() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'projects', action: 'new' },
            bubbles: true,
            composed: true
        }));
    }

    goToRepositories() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'repositories' },
            bubbles: true,
            composed: true
        }));
    }

    goToRepositoryDetail(event) {
        const recordId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'repositoryDetail', recordId },
            bubbles: true,
            composed: true
        }));
    }
}
