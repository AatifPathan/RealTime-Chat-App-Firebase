import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getContributors from '@salesforce/apex/ContributorController.getContributors';

export default class Contributors extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';

    searchTerm = '';
    contributors = [];
    searchDebounce;

    connectedCallback() {
        this.loadContributors();
    }

    loadContributors() {
        this.isLoading = true;
        this.hasError = false;
        getContributors({ searchTerm: this.searchTerm })
            .then((data) => {
                this.contributors = (data || []).map((c) => ({
                    ...c,
                    initials: this.initials(c.name)
                }));
                this.hasError = false;
            })
            .catch((error) => {
                this.hasError = true;
                this.errorMessage = this.reduceError(error);
                this.showErrorToast();
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    initials(name) {
        return (name || '').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get isEmpty() { return this.contributors.length === 0; }
    get totalCount() { return this.contributors.length; }

    handleSearch(event) {
        window.clearTimeout(this.searchDebounce);
        const value = event.target.value;
        this.searchDebounce = window.setTimeout(() => {
            this.searchTerm = value;
            this.loadContributors();
        }, 300);
    }

    handleCardClick(event) {
        const contributorId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'contributorProfile', recordId: contributorId },
            bubbles: true,
            composed: true
        }));
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred while loading contributors.';
    }

    showErrorToast() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Couldn\u2019t load contributors',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
