import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isGuest from '@salesforce/user/isGuest';
import getRepositoryList from '@salesforce/apex/RepositoryController.getRepositoryList';
import createRepository from '@salesforce/apex/RepositoryController.createRepository';
import getOrganizationOptions from '@salesforce/apex/OrganizationController.getOrganizationOptions';

const LANG_COLORS = {
    Apex: '#00a1e0', Java: '#e07524', JavaScript: '#f0db4f', Python: '#3572A5',
    'C++': '#00599c', 'C#': '#68217a', Go: '#00add8', PHP: '#787cb5',
    Ruby: '#cc342d', TypeScript: '#3178c6', Other: '#8a94a6'
};
const DIFF_CLASS = {
    Beginner: 'oc-badge oc-badge-green',
    Intermediate: 'oc-badge oc-badge-amber',
    Advanced: 'oc-badge oc-badge-red'
};
const STATUS_CLASS = {
    Active: 'oc-badge oc-badge-blue',
    Archived: 'oc-badge oc-badge-outline',
    'Under Maintenance': 'oc-badge oc-badge-purple'
};
const PAGE_SIZE = 10;

export default class Repositories extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';

    searchTerm = '';
    activeFilter = 'all';
    sortBy = 'name';
    sortAsc = true;
    pageNumber = 1;
    totalCount = 0;

    repos = [];
    searchDebounce;

    filters = [
        { label: 'All', value: 'all' },
        { label: 'Beginner', value: 'Beginner' },
        { label: 'Intermediate', value: 'Intermediate' },
        { label: 'Advanced', value: 'Advanced' },
        { label: 'Active', value: 'Active' },
        { label: 'Under Maintenance', value: 'Under Maintenance' }
    ].map((f) => ({ ...f, chipClass: f.value === 'all' ? 'oc-chip is-active' : 'oc-chip' }));

    showCreateModal = false;
    isCreating = false;
    createErrorMessage = '';
    createForm = { name: '', organizationId: '', primaryLanguage: '', difficultyLevel: '', status: 'Active', githubUrl: '', description: '' };
    organizationOptions = [];
    languageOptions = ['Apex', 'Java', 'JavaScript', 'Python', 'C++', 'C#', 'Go', 'PHP', 'Ruby', 'TypeScript', 'Other'];
    difficultyOptions = ['Beginner', 'Intermediate', 'Advanced'];
    statusOptions = ['Active', 'Archived', 'Under Maintenance'];

    connectedCallback() {
        this.loadRepositories();
    }

    loadRepositories() {
        this.isLoading = true;
        this.hasError = false;
        getRepositoryList({
            searchTerm: this.searchTerm,
            filterValue: this.activeFilter,
            sortBy: this.sortBy,
            sortAsc: this.sortAsc,
            pageNumber: this.pageNumber,
            pageSize: PAGE_SIZE
        })
            .then((result) => {
                this.totalCount = result.totalCount;
                this.repos = (result.repositories || []).map((r) => ({
                    ...r,
                    initials: this.initials(r.name),
                    langColor: `background:${LANG_COLORS[r.language] || '#999'}`,
                    diffClass: DIFF_CLASS[r.difficulty] || 'oc-badge',
                    statusClass: STATUS_CLASS[r.status] || 'oc-badge'
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
        return (name || '').split('-').map((p) => p[0]).join('').slice(0, 2).toUpperCase();
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get isEmpty() { return this.repos.length === 0; }
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
            this.loadRepositories();
        }, 300);
    }

    handleFilter(event) {
        this.activeFilter = event.target.dataset.value;
        this.pageNumber = 1;
        this.filters = this.filters.map((f) => ({
            ...f,
            chipClass: f.value === this.activeFilter ? 'oc-chip is-active' : 'oc-chip'
        }));
        this.loadRepositories();
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.sortBy === field) {
            this.sortAsc = !this.sortAsc;
        } else {
            this.sortBy = field;
            this.sortAsc = true;
        }
        this.loadRepositories();
    }

    handlePrevPage() {
        if (!this.isFirstPage) {
            this.pageNumber -= 1;
            this.loadRepositories();
        }
    }

    handleNextPage() {
        if (!this.isLastPage) {
            this.pageNumber += 1;
            this.loadRepositories();
        }
    }

    handleRowClick(event) {
        const repoId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'repositoryDetail', recordId: repoId },
            bubbles: true,
            composed: true
        }));
    }

    get createSubmitLabel() { return this.isCreating ? 'Adding…' : 'Add Repository'; }

    handleOpenCreate() {
        if (isGuest) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Log in required',
                message: 'Please log in to add a new repository.',
                variant: 'warning'
            }));
            return;
        }
        this.createForm = { name: '', organizationId: '', primaryLanguage: '', difficultyLevel: '', status: 'Active', githubUrl: '', description: '' };
        this.createErrorMessage = '';
        this.showCreateModal = true;
        getOrganizationOptions()
            .then((options) => {
                this.organizationOptions = options || [];
            })
            .catch((error) => {
                this.showErrorToast('Couldn\u2019t load organizations', this.reduceError(error));
            });
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
            this.createErrorMessage = 'Repository name is required.';
            return;
        }
        if (!this.createForm.organizationId) {
            this.createErrorMessage = 'Please select an organization.';
            return;
        }
        this.isCreating = true;
        this.createErrorMessage = '';
        createRepository({
            name: this.createForm.name.trim(),
            organizationId: this.createForm.organizationId,
            primaryLanguage: this.createForm.primaryLanguage,
            difficultyLevel: this.createForm.difficultyLevel,
            status: this.createForm.status,
            githubUrl: this.createForm.githubUrl,
            description: this.createForm.description
        })
            .then(() => {
                this.showCreateModal = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Repository added',
                    message: `${this.createForm.name} was added successfully.`,
                    variant: 'success'
                }));
                this.pageNumber = 1;
                this.loadRepositories();
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
        return 'An unexpected error occurred while loading repositories.';
    }

    showErrorToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title || 'Couldn\u2019t load repositories',
            message: message || this.errorMessage,
            variant: 'error'
        }));
    }
}
