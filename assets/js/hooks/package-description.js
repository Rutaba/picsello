const classes = {
  rotate: 'rotate-180',
  lineClamp2: 'line-clamp-2',
  hidden: 'hidden',
  rawHtmlInline: 'raw_html_inline',
};

export default {
  mounted() {
    const el = this.el;
    const event = el.dataset.event;
    const tooltip = el.querySelector('[role="tooltip"]');
    const description = el.querySelector('.raw_html');

    if (event === 'click') {
      const viewMoreBtn = el.querySelector('.view_more_click');
      const viewMoreText = viewMoreBtn?.querySelector('span');
      const viewMoreIcon = viewMoreBtn?.querySelector('svg');

      viewMoreBtn?.addEventListener('click', (e) => {
        if (description.classList.contains(classes.lineClamp2)) {
          description.classList.remove(
            classes.lineClamp2,
            classes.rawHtmlInline
          );
          viewMoreText.innerHTML = 'See less';
          viewMoreIcon.classList.add(classes.rotate);
        } else {
          description.classList.add(classes.lineClamp2, classes.rawHtmlInline);
          viewMoreText.innerHTML = 'See more';
          viewMoreIcon.classList.remove(classes.rotate);
        }
      });
    }

    if (event === 'mouseover') {
      el.querySelector('.view_more')?.addEventListener('mouseover', (e) => {
        tooltip.querySelector('.raw_html').innerHTML = description.innerHTML;
        tooltip.classList.remove(classes.hidden);
      });

      el.addEventListener('mouseleave', () =>
        tooltip.classList.add(classes.hidden)
      );
    }
  },
  updated() {
    const el = this.el;
    const event = el.dataset.event;
    const tooltip = el.querySelector('[role="tooltip"]');
    const description = el.querySelector('.raw_html');

    if (event === 'mouseover') {
      el.querySelector('.view_more')?.addEventListener('mouseover', (e) => {
        tooltip.querySelector('.raw_html').innerHTML = description.innerHTML;
        tooltip.classList.remove(classes.hidden);
      });

      el.addEventListener('mouseleave', () =>
        tooltip.classList.add(classes.hidden)
      );
    }
  },
};
