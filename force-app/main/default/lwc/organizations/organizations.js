import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isGuest from '@salesforce/user/isGuest';
import getOrganizations from '@salesforce/apex/OrganizationController.getOrganizations';
import createOrganization from '@salesforce/apex/OrganizationController.createOrganization';

const PAGE_SIZE = 9;
const LOGO_COLORS = ['#154aad', '#6f42c1', '#157a52', '#a3660c', '#c23934', '#2f6feb'];

export default class Organizations extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';

    searchTerm = '';
    pageNumber = 1;
    totalCount = 0;
    organizations = [];
    searchDebounce;

    showCreateModal = false;
    isCreating = false;
    createErrorMessage = '';
    createForm = { name: '', description: '', website: '', techStack: '' };

    connectedCallback() {
        this.loadOrganizations();
    }

    loadOrganizations() {
        this.isLoading = true;
        this.hasError = false;
        getOrganizations({
            searchTerm: this.searchTerm,
            sortBy: 'name',
            sortAsc: true,
            pageNumber: this.pageNumber,
            pageSize: PAGE_SIZE
        })
            .then((result) => {
                this.totalCount = result.totalCount;
                this.organizations = (result.organizations || []).map((o, index) => ({
                    ...o,
                    initials: this.initials(o.name),
                    logoStyle: `background:${LOGO_COLORS[index % LOGO_COLORS.length]}`
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
    get isEmpty() { return this.organizations.length === 0; }
    get totalPages() { return Math.max(1, Math.ceil(this.totalCount / PAGE_SIZE)); }
    get hasPagination() { return this.totalPages > 1; }
    get isFirstPage() { return this.pageNumber <= 1; }
    get isLastPage() { return this.pageNumber >= this.totalPages; }

    handleSearch(event) {
        window.clearTimeout(this.searchDebounce);
        const value = event.target.value;
        this.searchDebounce = window.setTimeout(() => {
            this.searchTerm = value;
            this.pageNumber = 1;
            this.loadOrganizations();
        }, 300);
    }

    handlePrevPage() {
        if (!this.isFirstPage) {
            this.pageNumber -= 1;
            this.loadOrganizations();
        }
    }

    handleNextPage() {
        if (!this.isLastPage) {
            this.pageNumber += 1;
            this.loadOrganizations();
        }
    }

    handleCardClick(event) {
        const orgId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'organizationDetail', recordId: orgId },
            bubbles: true,
            composed: true
        }));
    }

    get createSubmitLabel() { return this.isCreating ? 'Creating…' : 'Create Organization'; }

    handleOpenCreate() {
        if (isGuest) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Log in required',
                message: 'Please log in to add a new organization.',
                variant: 'warning'
            }));
            return;
        }
        this.createForm = { name: '', description: '', website: '', techStack: '' };
        this.createErrorMessage = '';
        this.showCreateModal = true;
    }

    handleCloseCreate() {
        this.showCreateModal = false;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleCreateFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.createForm = { ...this.createForm, [field]: event.target.value };
    }

    handleCreateSubmit() {
        if (!this.createForm.name || !this.createForm.name.trim()) {
            this.createErrorMessage = 'Organization name is required.';
            return;
        }
        this.isCreating = true;
        this.createErrorMessage = '';
        createOrganization({
            name: this.createForm.name.trim(),
            description: this.createForm.description,
            website: this.createForm.website,
            techStack: this.createForm.techStack
        })
            .then(() => {
                this.showCreateModal = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Organization created',
                    message: `${this.createForm.name} was added successfully.`,
                    variant: 'success'
                }));
                this.pageNumber = 1;
                this.loadOrganizations();
            })
            .catch((error) => {
                this.createErrorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isCreating = false;
            });
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred while loading organizations.';
    }

    showErrorToast() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Couldn\u2019t load organizations',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
