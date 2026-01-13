/**
 * Security Scanner - HTML Report Interactive Features
 * Tabs, Search, Sort, Copy-to-clipboard, Collapsible panels
 */

const SecurityReport = {
    // Initialize all features
    init() {
        this.initTabs();
        this.initSearch();
        this.initSort();
        this.initCopyButtons();
        this.initExpandButtons();
        this.updateCounts();
    },

    // Tab Navigation
    initTabs() {
        const tabs = document.querySelectorAll('.tab');
        const rows = document.querySelectorAll('.finding-row');

        tabs.forEach(tab => {
            tab.addEventListener('click', () => {
                // Update active tab
                tabs.forEach(t => t.classList.remove('active'));
                tab.classList.add('active');

                // Filter rows
                const severity = tab.dataset.severity;
                this.filterBySeverity(severity);
            });
        });
    },

    // Filter findings by severity
    filterBySeverity(severity) {
        const rows = document.querySelectorAll('.finding-row');
        let visibleCount = 0;

        rows.forEach(row => {
            const rowSeverity = row.dataset.severity;
            const matchesSearch = row.style.display !== 'none-search';

            if (severity === 'all' || rowSeverity === severity) {
                row.style.display = '';
                row.classList.remove('filtered-severity');
                visibleCount++;
            } else {
                row.style.display = 'none';
                row.classList.add('filtered-severity');
            }
        });

        // Show no results message
        this.toggleNoResults(visibleCount === 0);
    },

    // Search functionality
    initSearch() {
        const searchInput = document.getElementById('search-findings');
        const categoryFilter = document.getElementById('category-filter');

        if (searchInput) {
            searchInput.addEventListener('input', () => this.applyFilters());
        }

        if (categoryFilter) {
            categoryFilter.addEventListener('change', () => this.applyFilters());
        }
    },

    // Apply all filters (search + category)
    applyFilters() {
        const searchInput = document.getElementById('search-findings');
        const categoryFilter = document.getElementById('category-filter');
        const rows = document.querySelectorAll('.finding-row');

        const searchQuery = searchInput ? searchInput.value.toLowerCase().trim() : '';
        const categoryValue = categoryFilter ? categoryFilter.value : '';

        let visibleCount = 0;

        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            const category = row.dataset.category || '';

            const matchesSearch = !searchQuery || text.includes(searchQuery);
            const matchesCategory = !categoryValue || category === categoryValue;

            // Check if filtered by severity tab
            const isFilteredBySeverity = row.classList.contains('filtered-severity');

            if (matchesSearch && matchesCategory && !isFilteredBySeverity) {
                row.style.display = '';
                visibleCount++;
            } else {
                row.style.display = 'none';
            }
        });

        this.toggleNoResults(visibleCount === 0);
    },

    // Show/hide no results message
    toggleNoResults(show) {
        let noResults = document.querySelector('.no-results');

        if (show && !noResults) {
            noResults = document.createElement('div');
            noResults.className = 'no-results';
            const p = document.createElement('p');
            p.textContent = 'Arama kriterlerine uygun bulgu bulunamadı.';
            noResults.appendChild(p);
            const table = document.querySelector('.findings-table');
            if (table && table.parentNode) {
                table.parentNode.appendChild(noResults);
            }
        } else if (!show && noResults) {
            noResults.remove();
        }
    },

    // Table sorting
    initSort() {
        const headers = document.querySelectorAll('.findings-table th[data-sort]');

        headers.forEach(header => {
            header.addEventListener('click', () => {
                const sortKey = header.dataset.sort;
                const isAsc = header.classList.contains('sorted-asc');

                // Reset other headers
                headers.forEach(h => {
                    h.classList.remove('sorted', 'sorted-asc', 'sorted-desc');
                });

                // Set current sort
                header.classList.add('sorted', isAsc ? 'sorted-desc' : 'sorted-asc');

                this.sortTable(sortKey, !isAsc);
            });
        });
    },

    // Sort table rows
    sortTable(key, ascending) {
        const tbody = document.querySelector('.findings-table tbody');
        if (!tbody) return;

        const rows = Array.from(tbody.querySelectorAll('.finding-row'));

        const severityOrder = {
            'critical': 5,
            'high': 4,
            'medium': 3,
            'low': 2,
            'info': 1
        };

        rows.sort((a, b) => {
            let valueA, valueB;

            if (key === 'severity') {
                valueA = severityOrder[a.dataset.severity] || 0;
                valueB = severityOrder[b.dataset.severity] || 0;
            } else if (key === 'category') {
                valueA = a.dataset.category || '';
                valueB = b.dataset.category || '';
            } else if (key === 'title') {
                const titleA = a.querySelector('.finding-title');
                const titleB = b.querySelector('.finding-title');
                valueA = titleA ? titleA.textContent : '';
                valueB = titleB ? titleB.textContent : '';
            } else {
                valueA = a.textContent;
                valueB = b.textContent;
            }

            if (typeof valueA === 'string') {
                return ascending
                    ? valueA.localeCompare(valueB, 'tr')
                    : valueB.localeCompare(valueA, 'tr');
            }

            return ascending ? valueA - valueB : valueB - valueA;
        });

        // Re-append sorted rows
        rows.forEach(row => tbody.appendChild(row));
    },

    // Copy to clipboard
    initCopyButtons() {
        document.querySelectorAll('.copy-btn').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.preventDefault();
                const targetId = btn.dataset.target;
                const codeElement = document.getElementById(targetId);

                if (!codeElement) return;

                const text = codeElement.textContent.trim();

                try {
                    await navigator.clipboard.writeText(text);

                    // Visual feedback - safe DOM manipulation
                    btn.classList.add('copied');
                    const iconSpan = btn.querySelector('.icon');
                    const originalIcon = iconSpan ? iconSpan.textContent : '';
                    if (iconSpan) {
                        iconSpan.textContent = '[ok]';
                    }
                    btn.setAttribute('title', 'Kopyalandı!');

                    setTimeout(() => {
                        btn.classList.remove('copied');
                        if (iconSpan) {
                            iconSpan.textContent = originalIcon || '[ ]';
                        }
                        btn.setAttribute('title', 'Kopyala');
                    }, 2000);
                } catch (err) {
                    // Fallback for older browsers
                    const textarea = document.createElement('textarea');
                    textarea.value = text;
                    textarea.style.position = 'fixed';
                    textarea.style.opacity = '0';
                    document.body.appendChild(textarea);
                    textarea.select();
                    document.execCommand('copy');
                    document.body.removeChild(textarea);

                    btn.classList.add('copied');
                    setTimeout(() => btn.classList.remove('copied'), 2000);
                }
            });
        });
    },

    // Expand/collapse remediation panels
    initExpandButtons() {
        document.querySelectorAll('.btn-expand').forEach(btn => {
            btn.addEventListener('click', () => {
                const targetId = btn.dataset.target;
                const panel = document.getElementById(targetId);

                if (!panel) return;

                const isExpanded = panel.classList.contains('show');
                const textSpan = btn.querySelector('.btn-text');
                const arrowSpan = btn.querySelector('.arrow');

                if (isExpanded) {
                    panel.classList.remove('show');
                    btn.classList.remove('expanded');
                    if (textSpan) textSpan.textContent = 'Çözüm';
                    if (arrowSpan) arrowSpan.textContent = '▼';
                } else {
                    panel.classList.add('show');
                    btn.classList.add('expanded');
                    if (textSpan) textSpan.textContent = 'Kapat';
                    if (arrowSpan) arrowSpan.textContent = '▲';
                }
            });
        });
    },

    // Update tab counts based on visible rows
    updateCounts() {
        const severities = ['critical', 'high', 'medium', 'low', 'info'];

        severities.forEach(severity => {
            const count = document.querySelectorAll('.finding-row[data-severity="' + severity + '"]').length;
            const badge = document.querySelector('.tab[data-severity="' + severity + '"] .badge');
            if (badge) {
                badge.textContent = count;
            }
        });

        // Total count
        const totalCount = document.querySelectorAll('.finding-row').length;
        const allBadge = document.querySelector('.tab[data-severity="all"] .badge');
        if (allBadge) {
            allBadge.textContent = totalCount;
        }
    },

    // Expand all panels
    expandAll() {
        document.querySelectorAll('.remediation-panel').forEach(panel => {
            panel.classList.add('show');
        });
        document.querySelectorAll('.btn-expand').forEach(btn => {
            btn.classList.add('expanded');
            const textSpan = btn.querySelector('.btn-text');
            const arrowSpan = btn.querySelector('.arrow');
            if (textSpan) textSpan.textContent = 'Kapat';
            if (arrowSpan) arrowSpan.textContent = '▲';
        });
    },

    // Collapse all panels
    collapseAll() {
        document.querySelectorAll('.remediation-panel').forEach(panel => {
            panel.classList.remove('show');
        });
        document.querySelectorAll('.btn-expand').forEach(btn => {
            btn.classList.remove('expanded');
            const textSpan = btn.querySelector('.btn-text');
            const arrowSpan = btn.querySelector('.arrow');
            if (textSpan) textSpan.textContent = 'Çözüm';
            if (arrowSpan) arrowSpan.textContent = '▼';
        });
    }
};

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    SecurityReport.init();
});

// Export for global access
window.SecurityReport = SecurityReport;
