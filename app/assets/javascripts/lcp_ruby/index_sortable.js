// LCP Ruby — Index table drag-and-drop reordering
//
// Activated when <table class="lcp-table" data-reorder-url="..."> is present.
// Sends PATCH requests with relative positioning ({ after: id } or { before: id }).
// Handles list_version for concurrent edit detection.

(function () {
  document.addEventListener("DOMContentLoaded", function () {
    var table = document.querySelector("table.lcp-table[data-reorder-url]");
    if (!table) return;

    var reorderUrl = table.getAttribute("data-reorder-url");
    var listVersion = table.getAttribute("data-list-version");
    var tbody = table.querySelector("tbody");
    if (!tbody) return;

    var dragRow = null;
    var placeholder = null;

    function isDisabled() {
      return table.getAttribute("data-reorder-disabled") === "true";
    }

    function getCSRFToken() {
      var meta = document.querySelector('meta[name="csrf-token"]');
      return meta ? meta.getAttribute("content") : "";
    }

    function showFlash(message, type) {
      var existing = document.querySelector(".lcp-flash.lcp-reorder-flash");
      if (existing) existing.remove();

      var flash = document.createElement("div");
      flash.className = "lcp-flash lcp-reorder-flash " + (type === "error" ? "lcp-flash-alert" : "lcp-flash-notice");
      flash.textContent = message;

      var container = document.querySelector(".lcp-resources-index");
      if (container) {
        container.insertBefore(flash, container.firstChild);
      }

      setTimeout(function () { flash.remove(); }, 5000);
    }

    function buildUrl(recordId) {
      return reorderUrl.replace(":id", recordId).replace("%3Aid", recordId);
    }

    function getRecordId(row) {
      return row.getAttribute("data-record-id");
    }

    // Find the column index for the position field (if visible in the table).
    var positionColIndex = -1;
    (function () {
      var headers = table.querySelectorAll("thead th");
      for (var i = 0; i < headers.length; i++) {
        var link = headers[i].querySelector("a[href*='sort=position']");
        if (link) { positionColIndex = i; break; }
      }
    })();

    function updatePositionCells() {
      if (positionColIndex < 0) return;
      var rows = tbody.querySelectorAll("tr");
      rows.forEach(function (row, idx) {
        var cells = row.querySelectorAll("td");
        if (cells[positionColIndex]) {
          cells[positionColIndex].textContent = String(idx + 1);
        }
      });
    }

    function sendReorder(recordId, position) {
      var url = buildUrl(recordId);
      var body = { position: position };
      if (listVersion) {
        body.list_version = listVersion;
      }

      fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": getCSRFToken(),
          "Accept": "application/json"
        },
        body: JSON.stringify(body)
      }).then(function (response) {
        if (response.ok) {
          return response.json().then(function (data) {
            if (data.list_version) {
              listVersion = data.list_version;
              table.setAttribute("data-list-version", listVersion);
            }
            updatePositionCells();
          });
        } else if (response.status === 409) {
          showFlash("List was modified by another user, reloading...", "error");
          setTimeout(function () { window.location.reload(); }, 1500);
        } else if (response.status === 403) {
          showFlash("You are not authorized to reorder.", "error");
          window.location.reload();
        } else {
          showFlash("Failed to reorder. Please try again.", "error");
          window.location.reload();
        }
      }).catch(function () {
        showFlash("Network error. Please try again.", "error");
        window.location.reload();
      });
    }

    // --- Drag and drop handlers ---

    function onDragStart(e) {
      if (isDisabled()) { e.preventDefault(); return; }

      dragRow = e.target.closest("tr");
      if (!dragRow || !getRecordId(dragRow)) { e.preventDefault(); return; }

      dragRow.classList.add("dragging");
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/plain", getRecordId(dragRow));
    }

    function onDragOver(e) {
      e.preventDefault();
      if (!dragRow) return;

      var targetRow = e.target.closest("tr");
      if (!targetRow || targetRow === dragRow || !tbody.contains(targetRow)) return;

      // Remove all drag-over indicators
      tbody.querySelectorAll("tr.drag-over").forEach(function (r) {
        r.classList.remove("drag-over");
      });
      targetRow.classList.add("drag-over");
    }

    function onDragLeave(e) {
      var targetRow = e.target.closest("tr");
      if (targetRow) targetRow.classList.remove("drag-over");
    }

    function onDrop(e) {
      e.preventDefault();
      if (!dragRow) return;

      tbody.querySelectorAll("tr.drag-over").forEach(function (r) {
        r.classList.remove("drag-over");
      });

      var targetRow = e.target.closest("tr");
      if (!targetRow || targetRow === dragRow || !tbody.contains(targetRow)) {
        cleanupDrag();
        return;
      }

      // Determine position relative to target
      var rect = targetRow.getBoundingClientRect();
      var midY = rect.top + rect.height / 2;
      var dropAbove = e.clientY < midY;

      var recordId = getRecordId(dragRow);
      var position;

      if (dropAbove) {
        // Insert before target
        tbody.insertBefore(dragRow, targetRow);
        position = { before: parseInt(getRecordId(targetRow), 10) };
      } else {
        // Insert after target
        var nextSibling = targetRow.nextElementSibling;
        if (nextSibling) {
          tbody.insertBefore(dragRow, nextSibling);
        } else {
          tbody.appendChild(dragRow);
        }
        position = { after: parseInt(getRecordId(targetRow), 10) };
      }

      cleanupDrag();
      sendReorder(recordId, position);
    }

    function onDragEnd() {
      cleanupDrag();
    }

    function cleanupDrag() {
      if (dragRow) {
        dragRow.classList.remove("dragging");
        dragRow = null;
      }
      tbody.querySelectorAll("tr.drag-over").forEach(function (r) {
        r.classList.remove("drag-over");
      });
    }

    // --- Touch support ---

    var touchStartY = 0;
    var touchRow = null;

    function onTouchStart(e) {
      if (isDisabled()) return;
      if (!e.target.closest(".lcp-drag-handle")) return;

      touchRow = e.target.closest("tr");
      if (!touchRow || !getRecordId(touchRow)) return;

      touchStartY = e.touches[0].clientY;
      touchRow.classList.add("dragging");

      e.preventDefault();
    }

    function onTouchMove(e) {
      if (!touchRow) return;
      e.preventDefault();

      var touch = e.touches[0];
      var targetElement = document.elementFromPoint(touch.clientX, touch.clientY);
      if (!targetElement) return;

      var targetRow = targetElement.closest("tr");

      tbody.querySelectorAll("tr.drag-over").forEach(function (r) {
        r.classList.remove("drag-over");
      });

      if (targetRow && targetRow !== touchRow && tbody.contains(targetRow)) {
        targetRow.classList.add("drag-over");
      }
    }

    function onTouchEnd(e) {
      if (!touchRow) return;

      var touch = e.changedTouches[0];
      var targetElement = document.elementFromPoint(touch.clientX, touch.clientY);

      tbody.querySelectorAll("tr.drag-over").forEach(function (r) {
        r.classList.remove("drag-over");
      });

      if (targetElement) {
        var targetRow = targetElement.closest("tr");
        if (targetRow && targetRow !== touchRow && tbody.contains(targetRow)) {
          var rect = targetRow.getBoundingClientRect();
          var midY = rect.top + rect.height / 2;
          var dropAbove = touch.clientY < midY;

          var recordId = getRecordId(touchRow);
          var position;

          if (dropAbove) {
            tbody.insertBefore(touchRow, targetRow);
            position = { before: parseInt(getRecordId(targetRow), 10) };
          } else {
            var nextSibling = targetRow.nextElementSibling;
            if (nextSibling) {
              tbody.insertBefore(touchRow, nextSibling);
            } else {
              tbody.appendChild(touchRow);
            }
            position = { after: parseInt(getRecordId(targetRow), 10) };
          }

          touchRow.classList.remove("dragging");
          touchRow = null;
          sendReorder(recordId, position);
          return;
        }
      }

      if (touchRow) {
        touchRow.classList.remove("dragging");
        touchRow = null;
      }
    }

    // --- Attach event listeners ---

    // Make drag handles draggable
    var handles = tbody.querySelectorAll(".lcp-drag-handle");
    handles.forEach(function (handle) {
      var row = handle.closest("tr");
      if (row) row.setAttribute("draggable", "true");
    });

    tbody.addEventListener("dragstart", onDragStart);
    tbody.addEventListener("dragover", onDragOver);
    tbody.addEventListener("dragleave", onDragLeave);
    tbody.addEventListener("drop", onDrop);
    tbody.addEventListener("dragend", onDragEnd);

    // Touch events
    tbody.addEventListener("touchstart", onTouchStart, { passive: false });
    tbody.addEventListener("touchmove", onTouchMove, { passive: false });
    tbody.addEventListener("touchend", onTouchEnd);

    // Disable drag handles when reorder is disabled
    if (isDisabled()) {
      handles.forEach(function (handle) {
        handle.classList.add("lcp-drag-handle-disabled");
        handle.closest("tr").removeAttribute("draggable");
      });
    }
  });
})();
