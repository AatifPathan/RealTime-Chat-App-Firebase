import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getRepositoryDetail from '@salesforce/apex/RepositoryController.getRepositoryDetail';
import toggleBookmark from '@salesforce/apex/RepositoryController.toggleBookmark';
import syncFromGitHub from '@salesforce/apex/RepositoryController.syncFromGitHub';

const DIFF_CLASS = {
    Beginner: 'oc-badge oc-badge-green',
    Intermediate: 'oc-badge oc-badge-amber',
    Advanced: 'oc-badge oc-badge-red'
};

export default class RepositoryDetail extends LightningElement {
    @api recordId;

    isLoading = true;
    hasError = false;
    errorMessage = '';
    isMutating = false;
    isSyncing = false;
    isBookmarked = false;
    activeTab = 'readme';

    repo = {};
    description = '';
    githubUrl = '';
    readme = '';
    openIssues = [];
    contributors = [];
    activity = [];

    wiredResult;

    tabs = [
        { label: 'README', value: 'readme' },
        { label: 'Issues', value: 'issues' },
        { label: 'Contributors', value: 'contributors' }
    ].map((t) => ({ ...t, tabClass: t.value === 'readme' ? 'oc-tab is-active' : 'oc-tab' }));

    @wire(getRepositoryDetail, { repositoryId: '$recordId' })
    wiredRepo(result) {
        this.wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.hasError = false;
            this.applyData(data);
        } else if (error) {
            this.hasError = true;
            this.errorMessage = this.reduceError(error);
            this.showErrorToast('Couldn\u2019t load repository', this.errorMessage);
        }
    }

    applyData(data) {
        const r = data.repository || {};
        this.repo = {
            ...r,
            initials: this.initials(r.name),
            diffClass: DIFF_CLASS[r.difficulty] || 'oc-badge'
        };
        this.description = data.description;
        this.githubUrl = data.githubUrl;
        this.readme = data.readme;

        this.openIssues = (data.openIssues || []).map((i) => ({
            ...i,
            diffClass: DIFF_CLASS[i.difficulty] || 'oc-badge'
        }));

        this.contributors = (data.contributors || []).map((c) => ({
            ...c,
            initials: this.initials(c.name)
        }));

        this.activity = (data.activity || []).map((a) => ({
            ...a,
            meta: this.formatRelativeTime(a.timestamp)
        }));
    }

    initials(name) {
        return (name || '').split('-').map((p) => p[0]).join('').slice(0, 2).toUpperCase();
    }

    formatRelativeTime(isoString) {
        if (!isoString) return '';
        const minutes = Math.floor((Date.now() - new Date(isoString).getTime()) / 60000);
        if (minutes < 60) return `${minutes} min ago`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours} hr ago`;
        return `${Math.floor(hours / 24)} day(s) ago`;
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get showReadme() { return this.activeTab === 'readme'; }
    get showIssues() { return this.activeTab === 'issues'; }
    get showContributors() { return this.activeTab === 'contributors'; }
    get hasOpenIssues() { return this.openIssues.length > 0; }
    get hasContributors() { return this.contributors.length > 0; }
    get hasActivity() { return this.activity.length > 0; }
    get bookmarkLabel() { return this.isBookmarked ? '★ Bookmarked' : '☆ Bookmark'; }
    get syncLabel() { return this.isSyncing ? 'Syncing…' : '⟳ Sync from GitHub'; }

    handleSync() {
        this.isSyncing = true;
        syncFromGitHub({ repositoryId: this.recordId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Sync complete',
                    message: 'Repository stats refreshed from GitHub.',
                    variant: 'success'
                }));
                return refreshApex(this.wiredResult);
            })
            .catch((error) => {
                this.showErrorToast('Couldn\u2019t sync from GitHub', this.reduceError(error));
            })
            .finally(() => {
                this.isSyncing = false;
            });
    }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.value;
        this.tabs = this.tabs.map((t) => ({ ...t, tabClass: t.value === this.activeTab ? 'oc-tab is-active' : 'oc-tab' }));
    }

    handleBookmark() {
        this.isMutating = true;
        this.isBookmarked = !this.isBookmarked;
        toggleBookmark({ repositoryId: this.recordId, contributorId: null, isBookmarked: this.isBookmarked })
            .catch((error) => {
                this.isBookmarked = !this.isBookmarked;
                this.showErrorToast('Couldn\u2019t update bookmark', this.reduceError(error));
            })
            .finally(() => {
                this.isMutating = false;
            });
    }

    handleApply() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'issues', recordId: this.recordId },
            bubbles: true,
            composed: true
        }));
    }

    handleIssueClick(event) {
        const issueId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'issueDetail', recordId: issueId },
            bubbles: true,
            composed: true
        }));
    }

    handleRetry() {
        this.isLoading = true;
        this.hasError = false;
        refreshApex(this.wiredResult).finally(() => { this.isLoading = false; });
    }

    goToRepositories() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'repositories' },
            bubbles: true,
            composed: true
        }));
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }

    showErrorToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }
}
