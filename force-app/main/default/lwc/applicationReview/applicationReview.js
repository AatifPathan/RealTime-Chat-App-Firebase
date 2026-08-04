import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getApplicationReview from '@salesforce/apex/ApplicationController.getApplicationReview';
import updateApplicationStatus from '@salesforce/apex/ApplicationController.updateApplicationStatus';

export default class ApplicationReview extends LightningElement {
    @api recordId;

    isLoading = true;
    hasError = false;
    errorMessage = '';
    decision = '';
    reviewComments = '';

    issueTitle = '';
    repositoryName = '';
    appliedDateLabel = '';
    applicantName = '';
    applicantTitle = '';
    applicantBio = '';
    applicantReputation = 0;
    applicantGithub = '';
    applicantSkills = [];
    applicantInitials = '';

    wiredResult;

    @wire(getApplicationReview, { applicationId: '$recordId' })
    wiredReview(result) {
        this.wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.hasError = false;
            this.applyData(data);
        } else if (error) {
            this.hasError = true;
            this.errorMessage = this.reduceError(error);
            this.showErrorToast('Couldn\u2019t load application', this.errorMessage);
        }
    }

    applyData(data) {
        const app = data.application || {};
        this.issueTitle = app.issueTitle;
        this.repositoryName = app.repositoryName;
        this.appliedDateLabel = this.formatDate(app.appliedDate);
        this.decision = app.status === 'Approved' ? 'approved' : app.status === 'Rejected' ? 'rejected' : '';

        this.applicantName = data.applicantName;
        this.applicantTitle = data.applicantTitle;
        this.applicantBio = data.applicantBio;
        this.applicantReputation = data.applicantReputation;
        this.applicantGithub = data.applicantGithub;
        this.applicantSkills = data.applicantSkills || [];
        this.applicantInitials = this.initials(data.applicantName);
    }

    initials(name) {
        return (name || '').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
    }

    formatDate(dateString) {
        if (!dateString) return '';
        return new Date(dateString).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get hasSkills() { return this.applicantSkills.length > 0; }
    get decisionMade() { return this.decision !== ''; }
    get isDecided() { return this.decisionMade; }
    get commentsRequiredNote() { return true; }
    get githubUrl() { return this.applicantGithub ? `https://github.com/${this.applicantGithub}` : ''; }

    handleCommentsChange(event) {
        this.reviewComments = event.target.value;
    }

    get decisionMessage() {
        return this.decision === 'approved'
            ? `${this.applicantName}'s application has been approved.`
            : `${this.applicantName}'s application has been rejected.`;
    }

    handleApprove() {
        this.updateStatus('Approved');
    }

    handleReject() {
        if (!this.reviewComments || !this.reviewComments.trim()) {
            this.showErrorToast('Comments required', 'Please add review comments before rejecting an application.');
            return;
        }
        this.updateStatus('Rejected');
    }

    updateStatus(newStatus) {
        updateApplicationStatus({ applicationId: this.recordId, newStatus, reviewComments: this.reviewComments })
            .then(() => {
                this.decision = newStatus.toLowerCase();
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Application updated',
                    message: `Application ${newStatus.toLowerCase()}.`,
                    variant: 'success'
                }));
                return refreshApex(this.wiredResult);
            })
            .catch((error) => {
                this.showErrorToast('Couldn\u2019t update application', this.reduceError(error));
            });
    }

    goToApplications() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'applications' },
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

    showErrorToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }
}
