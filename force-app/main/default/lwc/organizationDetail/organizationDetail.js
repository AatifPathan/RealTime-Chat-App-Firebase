import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getOrganizationDetail from '@salesforce/apex/OrganizationController.getOrganizationDetail';

export default class OrganizationDetail extends LightningElement {
    @api recordId;

    isLoading = true;
    hasError = false;
    errorMessage = '';

    org = {};
    mentorName = '';
    repositories = [];
    projects = [];
    contributors = [];

    wiredResult;

    @wire(getOrganizationDetail, { organizationId: '$recordId' })
    wiredOrg(result) {
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
        const o = data.organization || {};
        this.org = { ...o, initials: this.initials(o.name), logoStyle: `background:${this.colorFor(o.name)}` };
        this.mentorName = data.mentorName;

        this.repositories = (data.repositories || []);
        this.projects = (data.projects || []).map((p) => ({ ...p, style: `width:${p.progress}%` }));
        this.contributors = (data.contributors || []).map((c) => ({ ...c, initials: this.initials(c.name) }));
    }

    initials(name) {
        return (name || '').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
    }

    colorFor(name) {
        const palette = ['#154aad', '#6f42c1', '#157a52', '#a3660c', '#c23934', '#2f6feb'];
        let hash = 0;
        for (let i = 0; i < (name || '').length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash);
        }
        return palette[Math.abs(hash) % palette.length];
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get hasRepositories() { return this.repositories.length > 0; }
    get hasProjects() { return this.projects.length > 0; }
    get hasContributors() { return this.contributors.length > 0; }

    goToRepositoryDetail(event) {
        const recordId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'repositoryDetail', recordId },
            bubbles: true,
            composed: true
        }));
    }

    goToOrganizations() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'organizations' },
            bubbles: true,
            composed: true
        }));
    }

    handleRetry() {
        this.isLoading = true;
        this.hasError = false;
        refreshApex(this.wiredResult).finally(() => { this.isLoading = false; });
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }

    showErrorToast() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Couldn\u2019t load organization',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
