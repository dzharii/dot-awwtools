/**
 * Render pasties dynamically on the web page.
 * @param {Object[]} pasties - An array of pasty objects.
 */
function renderPasties(pasties) {
    const pastyContainer = $find('#pastyContainer');

    pasties.forEach(pasty => {
      const pastyElement = $make('div');
      pastyElement.classList.add('pasty');

      const contentElement = $make('div');

      contentElement.innerHTML = $sanitize(pasty.content);
      contentElement.classList.add('pasty-content');
      pastyElement.appendChild(contentElement);

      contentElement.addEventListener('click', () => {
        contentElement.contentEditable = true;
        contentElement.focus();
      });

      contentElement.addEventListener('blur', () => {
        contentElement.contentEditable = false;
      });

      const copyButton = $make('button');
      copyButton.textContent = 'Copy content';
      copyButton.addEventListener('click', () => {
        const range = document.createRange();
        range.selectNodeContents(contentElement);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
        document.execCommand('copy');
        selection.removeAllRanges();
      });
      pastyElement.appendChild(copyButton);

      pastyContainer.appendChild(pastyElement);
    });
  }

  // Invoke the renderPasties function with the PASTIES data
  renderPasties(window.PASTIES);

/** LIBRARY  */

/**
 * Sanitize HTML to prevent XSS attacks.
 * @param {string} html
 * @returns {string}
 */
function $sanitize(html) {
    const el = $make('div');
    el.textContent = html;

    let contentHtml = el.innerHTML;
    // replace phpBB style tags with html
    contentHtml = contentHtml.replace(/\[b\]/g, '<b class="bb-bold">');
    contentHtml = contentHtml.replace(/\[\/b\]/g, '</b>');
    contentHtml = contentHtml.replace(/\[i\]/g, '<i class="bb-italic">');
    contentHtml = contentHtml.replace(/\[\/i\]/g, '</i>');
    contentHtml = contentHtml.replace(/\[u\]/g, '<u class="bb-underline">');
    contentHtml = contentHtml.replace(/\[\/u\]/g, '</u>');
    contentHtml = contentHtml.replace(/\[s\]/g, '<s class="bb-strikeout">');
    contentHtml = contentHtml.replace(/\[\/s\]/g, '</s>');

    return contentHtml;
}

/**
 *
 * @param {string} selector
 * @returns {*}
 */
function $find(selector) {
    const el = document.querySelector(selector);
    if (!el) {
        throw new Error(`$find: Unable to find element selector=${selector}`);
    }
    return el;
}

/**
 *
 * @param {string} tag
 * @param {any} [attrs]
 * @returns {*}
 */
function $make(tag, attrs) {
    const el = document.createElement(tag);
    if (attrs && typeof attrs === 'object') {
        for (const prop of Object.getOwnPropertyNames(attrs)) {
            el.setAttribute(prop, attrs[prop]);
        }
    }
    return el;
}


/**
 * Code from StackOverflow Q105034
 * @returns {string}
 */
function generateUUID() { // Public Domain/MIT
    var d = new Date().getTime();//Timestamp
    //Time in microseconds since page-load or 0 if unsupported
    var d2 = ((typeof performance !== 'undefined') && performance.now && (performance.now()*1000)) || 0;
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16;//random number between 0 and 16
        if(d > 0){//Use timestamp until depleted
            r = (d + r)%16 | 0;
            d = Math.floor(d/16);
        } else {//Use microseconds since page-load if supported
            r = (d2 + r)%16 | 0;
            d2 = Math.floor(d2/16);
        }
        return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    });
}