/*
 * 編輯器橋接。CSP 是 script-src 'self'，沒有 'unsafe-eval'——這個檔案裡
 * **不可以**出現 eval 或動態產生函式，那在兩個引擎上都會被擋掉，而且是只有
 * 真機才看得到的執行期失敗。
 *
 * 對外只有 window.__tatEditor 這一個物件，宿主用 evaluateJavascript 呼叫它。
 */
(function () {
  'use strict';

  var ed = document.getElementById('ed');
  var sourceMode = false;

  /* 進 execCommand 的引數只能來自這裡。宿主那端是 EditorCommand enum，
     兩邊的字面值必須一致。 */
  var BLOCKS = { p: 'p', h3: 'h3', h4: 'h4', h5: 'h5' };
  var INLINE = {
    bold: 'bold',
    italic: 'italic',
    underline: 'underline',
    strikeThrough: 'strikeThrough',
    removeFormat: 'removeFormat'
  };
  var LISTS = { ul: 'insertUnorderedList', ol: 'insertOrderedList' };

  function call(name, arg) {
    var bridge = window.flutter_inappwebview;
    if (!bridge || !bridge.callHandler) return;
    try {
      bridge.callHandler(name, arg);
    } catch (e) {
      /* 橋接還沒接好就算了，宿主那邊有逾時。 */
    }
  }

  function run(command, value) {
    try {
      document.execCommand(command, false, value);
    } catch (e) {
      return;
    }
  }

  function queryState(command) {
    try {
      return document.queryCommandState(command) === true;
    } catch (e) {
      return false;
    }
  }

  function currentBlock() {
    var value;
    try {
      value = document.queryCommandValue('formatBlock');
    } catch (e) {
      return '';
    }
    if (typeof value !== 'string') return '';
    var lower = value.toLowerCase();
    return Object.prototype.hasOwnProperty.call(BLOCKS, lower) ? lower : '';
  }

  function state() {
    if (sourceMode) return { block: '' };
    return {
      bold: queryState('bold'),
      italic: queryState('italic'),
      underline: queryState('underline'),
      strikeThrough: queryState('strikeThrough'),
      ul: queryState('insertUnorderedList'),
      ol: queryState('insertOrderedList'),
      block: currentBlock()
    };
  }

  function pushState() {
    call('tatEditorState', state());
  }

  window.__tatEditor = {
    /* 貼文 HTML 進來的唯一入口。innerHTML 不會執行 <script>，而注入之後
       CSP 也擋掉了 on*= 與 <script>，所以這裡不再自己過濾一次。 */
    setContent: function (html) {
      if (sourceMode) {
        ed.textContent = html;
      } else {
        ed.innerHTML = html;
      }
      pushState();
    },

    getContent: function () {
      return sourceMode ? ed.textContent : ed.innerHTML;
    },

    /* 原始碼模式：同一個 #ed，內容在「算繪過的 HTML」與「HTML 原始碼純文字」
       之間換手。切換時一定要把目前的內容帶過去，不然使用者的編輯會消失。 */
    setSourceMode: function (on) {
      var next = on === true;
      if (next === sourceMode) return;
      var carried = sourceMode ? ed.textContent : ed.innerHTML;
      sourceMode = next;
      if (sourceMode) {
        ed.classList.add('source');
        ed.textContent = carried;
      } else {
        ed.classList.remove('source');
        ed.innerHTML = carried;
      }
      pushState();
    },

    exec: function (token) {
      if (sourceMode) return;
      ed.focus();
      if (Object.prototype.hasOwnProperty.call(INLINE, token)) {
        run(INLINE[token]);
      } else if (Object.prototype.hasOwnProperty.call(LISTS, token)) {
        run(LISTS[token]);
      } else if (Object.prototype.hasOwnProperty.call(BLOCKS, token)) {
        run('formatBlock', '<' + BLOCKS[token] + '>');
      } else {
        return;
      }
      pushState();
    },

    state: state
  };

  document.addEventListener('selectionchange', pushState);

  /* input 另外送一顆訊號：宿主要靠它分辨「使用者真的改過東西」與「只是把
     游標移來移去」，離開時的放棄草稿確認完全建立在這個差別上。 */
  ed.addEventListener('input', function () {
    pushState();
    call('tatEditorInput', null);
  });

  /* contenteditable 裡的連結還是可以點。宿主已經把所有導覽都攔掉了，這裡
     再擋一次是為了不要在點擊當下就把游標與選取狀態弄掉。 */
  ed.addEventListener('click', function (event) {
    var node = event.target;
    while (node && node !== ed) {
      if (node.tagName === 'A') {
        event.preventDefault();
        return;
      }
      node = node.parentNode;
    }
  });

  /* 握手只送一次，但橋接不見得在 DOMContentLoaded 當下就裝好了（外掛是用
     document-start 的 user script 注入的）。沒裝好就每 50ms 再試一次，
     宿主那邊的逾時比這裡的總時長還久。 */
  var readyTries = 0;

  function ready() {
    var bridge = window.flutter_inappwebview;
    if (bridge && bridge.callHandler) {
      call('tatEditorReady', null);
      return;
    }
    if (readyTries++ >= 60) return;
    window.setTimeout(ready, 50);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', ready);
  } else {
    ready();
  }
})();
