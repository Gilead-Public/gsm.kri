// Toggle visibility of nested flag change lists

document.addEventListener('DOMContentLoaded', function() {
  // Hide all nested lists by default
  document.querySelectorAll('.flag-change-nested, .flag-change-details').forEach(function(ul) {
    ul.style.display = 'none';
  });

  // Show red flag sections by default
  document.querySelectorAll('.flag-change-nested.flag-change-expanded').forEach(function(ul) {
    ul.style.display = 'block';
  });

  // Add click event to parent items to toggle nested list
  document.querySelectorAll('.flag-change-parent').forEach(function(li) {
    li.style.cursor = 'pointer';
    li.classList.add('expandable');
    var nested = li.querySelector('.flag-change-nested');
    if (nested && nested.style.display === 'block') {
      li.classList.add('expanded');
    }
    li.addEventListener('click', function(e) {
      // Only toggle if clicking the parent, not a nested item
      if (e.target === li) {
        if (nested) {
          var isOpen = nested.style.display === 'block';
          nested.style.display = isOpen ? 'none' : 'block';
          li.classList.toggle('expanded', !isOpen);
        }
      }
    });
  });

  // Add/remove 'expanded' class to flag-change-item when toggled
  document.querySelectorAll('.flag-change-item').forEach(function(li) {
    li.classList.add('expandable');
    var details = li.querySelector('.flag-change-details');
    if (details && details.style.display === 'block') {
      li.classList.add('expanded');
    }
    li.style.cursor = 'pointer';
    li.addEventListener('click', function(e) {
      if (e.target === li) {
        if (details) {
          var isOpen = details.style.display === 'block';
          details.style.display = isOpen ? 'none' : 'block';
          li.classList.toggle('expanded', !isOpen);
        }
      }
      e.stopPropagation();
    });
  });

  // Show red flag sections by default (on initial render only)
  function expandRedFlags() {
    document.querySelectorAll('.flag-change-parent').forEach(function(li) {
      var nested = li.querySelector('.flag-change-nested');
      if (nested && li.innerHTML.includes("color:red")) {
        nested.style.display = 'block';
        li.classList.add('expanded');
      }
    });
  }
  // Initial render: expand red flags
  expandRedFlags();

  // Expand All / Collapse All functionality
  document.querySelectorAll('.change-expand-all').forEach(function(link) {
    link.style.cursor = 'pointer';
    link.addEventListener('click', function(e) {
      e.preventDefault();
      // Expand all parent and item lists
      document.querySelectorAll('.flag-change-nested').forEach(function(ul) {
        ul.style.display = 'block';
      });
      document.querySelectorAll('.flag-change-details').forEach(function(ul) {
        ul.style.display = 'block';
      });
      document.querySelectorAll('.flag-change-parent, .flag-change-item').forEach(function(li) {
        li.classList.add('expanded');
      });
    });
  });
  document.querySelectorAll('.change-collapse-all').forEach(function(link) {
    link.style.cursor = 'pointer';
    link.addEventListener('click', function(e) {
      e.preventDefault();
      // Collapse all parent and item lists (including red flags)
      document.querySelectorAll('.flag-change-nested').forEach(function(ul) {
        ul.style.display = 'none';
      });
      document.querySelectorAll('.flag-change-details').forEach(function(ul) {
        ul.style.display = 'none';
      });
      document.querySelectorAll('.flag-change-parent, .flag-change-item').forEach(function(li) {
        li.classList.remove('expanded');
      });
    });
  });
});
