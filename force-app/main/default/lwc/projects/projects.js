import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isGuest from '@salesforce/user/isGuest';
import getProjects from '@salesforce/apex/ProjectController.getProjects';
import createProject from '@salesforce/apex/ProjectController.createProject';
import getOrganizationOptions from '@salesforce/apex/OrganizationController.getOrganizationOptions';

const STATUS_CLASS = {
    Active: 'oc-badge oc-badge-blue',
    'On Hold': 'oc-badge oc-badge-amber',
    Completed: 'oc-badge oc-badge-green',
    Planning: 'oc-badge oc-badge-outline',
    Cancelled: 'oc-badge oc-badge-red'
};
const DIFF_CLASS = {
    Beginner: 'oc-badge oc-badge-green',
    Intermediate: 'oc-badge oc-badge-amber',
    Advanced: 'oc-badge oc-badge-red'
};

export default class Projects extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';

    searchTerm = '';
    activeFilter = 'all';
    projects = [];
    searchDebounce;

    filters = [
        { label: 'All', value: 'all' },
        { label: 'Planning', value: 'Planning' },
        { label: 'Active', value: 'Active' },
        { label: 'On Hold', value: 'On Hold' },
        { label: 'Completed', value: 'Completed' },
        { label: 'Cancelled', value: 'Cancelled' }
    ].map((f) => ({ ...f, chipClass: f.value === 'all' ? 'oc-chip is-active' : 'oc-chip' }));

    showCreateModal = false;
    isCreating = false;
    createErrorMessage = '';
    createForm = { name: '', organizationId: '', status: 'Planning', endDate: '', description: '' };
    organizationOptions = [];
    statusOptions = ['Planning', 'Active', 'On Hold', 'Completed', 'Cancelled'];

    connectedCallback() {
        this.loadProjects();
    }

    loadProjects() {
        this.isLoading = true;
        this.hasError = false;
        getProjects({ searchTerm: this.searchTerm, statusFilter: this.activeFilter })
            .then((data) => {
                this.projects = (data || []).map((p) => ({
                    ...p,
                    statusClass: STATUS_CLASS[p.status] || 'oc-badge',
                    diffClass: DIFF_CLASS[p.difficulty] || 'oc-badge',
                    style: `width:${p.progress}%`
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

    get showContent() { return !this.isLoading && !this.hasError; }
    get isEmpty() { return this.projects.length === 0; }

    handleSearch(event) {
        window.clearTimeout(this.searchDebounce);
        const value = event.target.value;
        this.searchDebounce = window.setTimeout(() => {
            this.searchTerm = value;
            this.loadProjects();
        }, 300);
    }

    handleFilter(event) {
        this.activeFilter = event.target.dataset.value;
        this.filters = this.filters.map((f) => ({
            ...f,
            chipClass: f.value === this.activeFilter ? 'oc-chip is-active' : 'oc-chip'
        }));
        this.loadProjects();
    }

    handleCardClick(event) {
        const projectId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'projectDetail', recordId: projectId },
            bubbles: true,
            composed: true
        }));
    }

    get createSubmitLabel() { return this.isCreating ? 'Creating…' : 'Create Project'; }

    handleOpenCreate() {
        if (isGuest) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Log in required',
                message: 'Please log in to add a new project.',
                variant: 'warning'
            }));
            return;
        }
        this.createForm = { name: '', organizationId: '', status: 'Planning', endDate: '', description: '' };
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
            this.createErrorMessage = 'Project name is required.';
            return;
        }
        if (!this.createForm.organizationId) {
            this.createErrorMessage = 'Please select an organization.';
            return;
        }
        this.isCreating = true;
        this.createErrorMessage = '';
        createProject({
            name: this.createForm.name.trim(),
            organizationId: this.createForm.organizationId,
            description: this.createForm.description,
            status: this.createForm.status,
            endDate: this.createForm.endDate || null
        })
            .then(() => {
                this.showCreateModal = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Project created',
                    message: `${this.createForm.name} was added successfully.`,
                    variant: 'success'
                }));
                this.loadProjects();
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
        return 'An unexpected error occurred while loading projects.';
    }

    showErrorToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title || 'Couldn\u2019t load projects',
            message: message || this.errorMessage,
            variant: 'error'
        }));
    }
}
