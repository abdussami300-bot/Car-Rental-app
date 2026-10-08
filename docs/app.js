/**
 * SAYYARAH Privacy Policy Interactive Logic
 */

document.addEventListener("DOMContentLoaded", () => {
  const header = document.querySelector(".site-header");
  const progressBar = document.querySelector(".scroll-progress-bar");
  const backToTopBtn = document.querySelector(".back-to-top");
  const mobileToggle = document.querySelector(".mobile-menu-toggle");
  const mobileDrawer = document.querySelector(".mobile-drawer");
  const tocLinks = document.querySelectorAll(".toc-link");
  const sections = document.querySelectorAll(".policy-section");
  const copyBtn = document.querySelector(".copy-email-button");

  // 1. Scroll Events (Progress Bar, Sticky Header Elevation, Back-to-Top)
  const handleScroll = () => {
    const scrollTop = window.scrollY || document.documentElement.scrollTop;
    const docHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight;
    const scrollPercent = docHeight > 0 ? (scrollTop / docHeight) * 100 : 0;

    // Progress Bar
    if (progressBar) {
      progressBar.style.width = `${scrollPercent}%`;
    }

    // Header elevation
    if (header) {
      if (scrollTop > 20) {
        header.classList.add("scrolled");
      } else {
        header.classList.remove("scrolled");
      }
    }

    // Back to top button
    if (backToTopBtn) {
      if (scrollTop > 350) {
        backToTopBtn.classList.add("visible");
      } else {
        backToTopBtn.classList.remove("visible");
      }
    }
  };

  window.addEventListener("scroll", handleScroll, { passive: true });
  handleScroll(); // Initial run

  // 2. Back to top scroll
  if (backToTopBtn) {
    backToTopBtn.addEventListener("click", () => {
      window.scrollTo({
        top: 0,
        behavior: "smooth"
      });
    });
  }

  // 3. Mobile Menu Toggle
  if (mobileToggle && mobileDrawer) {
    mobileToggle.addEventListener("click", () => {
      const isOpen = mobileDrawer.classList.toggle("open");
      mobileToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
    });

    // Close drawer when clicking a link inside it
    mobileDrawer.querySelectorAll("a").forEach(link => {
      link.addEventListener("click", () => {
        mobileDrawer.classList.remove("open");
        mobileToggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  // 4. Table of Contents Intersection Observer (Scrollspy)
  if (sections.length > 0 && tocLinks.length > 0) {
    const observerOptions = {
      root: null,
      rootMargin: "-90px 0px -70% 0px",
      threshold: 0
    };

    const sectionObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const id = entry.target.getAttribute("id");
          tocLinks.forEach(link => {
            if (link.getAttribute("href") === `#${id}`) {
              link.classList.add("active");
              // Scroll active link into view in sidebar if needed
              link.scrollIntoView({ block: "nearest", behavior: "smooth" });
            } else {
              link.classList.remove("active");
            }
          });
        }
      });
    }, observerOptions);

    sections.forEach(section => sectionObserver.observe(section));
  }

  // 5. Copy Email Helper with Visual Feedback
  if (copyBtn) {
    copyBtn.addEventListener("click", () => {
      const email = "abdussami039@gmail.com";
      navigator.clipboard.writeText(email).then(() => {
        const originalText = copyBtn.innerHTML;
        copyBtn.innerHTML = `
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="color:#00B4D8">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>
          Copied!
        `;
        setTimeout(() => {
          copyBtn.innerHTML = originalText;
        }, 2200);
      }).catch(() => {
        // Fallback prompt if clipboard API is restricted
        window.location.href = `mailto:${email}`;
      });
    });
  }
});
