/* rc-tech panel — vanilla JS, polling 60s, row actions, sidebar lazy */
(function () {
  'use strict';
  if ( ! window.rcTech ) return;

  const { restUrl, nonce, pollInterval, currentUser, i18n } = window.rcTech;
  let pollTimer = null;
  let pollFails = 0;

  function api( path, opts = {} ) {
    const init = Object.assign( {
      headers: { 'X-WP-Nonce': nonce, 'Content-Type': 'application/json' },
      credentials: 'same-origin',
    }, opts );
    return fetch( restUrl + path, init ).then( r => {
      if ( ! r.ok ) return r.json().then( j => Promise.reject( j ) );
      return r.json();
    } );
  }

  function toast( msg, isError = false ) {
    const t = document.createElement( 'div' );
    t.className = 'rc-tech-toast' + ( isError ? ' error' : '' );
    t.textContent = msg;
    document.body.appendChild( t );
    setTimeout( () => t.remove(), 3500 );
  }

  function filters() {
    return {
      os: document.getElementById( 'rc-tech-os' ).value,
      only_mine: document.getElementById( 'rc-tech-only-mine' ).checked ? 1 : 0,
      only_unassigned: document.getElementById( 'rc-tech-only-unassigned' ).checked ? 1 : 0,
      q: document.getElementById( 'rc-tech-q' ).value,
    };
  }

  function refresh() {
    const f = filters();
    const qs = new URLSearchParams( f ).toString();
    api( 'queue?' + qs ).then( data => {
      pollFails = 0;
      renderRows( data.rows || [] );
      renderKpis( data.kpis || {} );
      document.getElementById( 'rc-tech-updated' ).textContent =
        'Actualizado: ' + new Date().toLocaleTimeString();
    } ).catch( err => {
      pollFails++;
      if ( pollFails >= 3 ) {
        clearInterval( pollTimer );
        pollTimer = null;
        toast( 'Polling pausado tras 3 fallos. Refresca manualmente.', true );
      }
      console.error( '[rc-tech]', err );
    } );
  }

  function renderKpis( k ) {
    const kpis = document.querySelectorAll( '.rc-tech-kpis .kpi .num' );
    if ( kpis.length >= 4 ) {
      kpis[0].textContent = k.open ?? 0;
      kpis[1].textContent = k.mine ?? 0;
      kpis[2].textContent = k.overdue ?? 0;
      kpis[3].textContent = k.fleet_score ?? '—';
      kpis[2].parentElement.classList.toggle( 'red', ( k.overdue || 0 ) > 0 );
    }
  }

  function renderRows( rows ) {
    const tbody = document.getElementById( 'rc-tech-rows' );
    if ( ! rows.length ) {
      tbody.innerHTML = '<tr><td colspan="9"><em>Sin tickets en cola.</em></td></tr>';
    } else {
      tbody.innerHTML = rows.map( rowHtml ).join( '' );
    }
    renderKanban( rows );
  }

  function renderKanban( rows ) {
    const kb = document.getElementById( 'rc-tech-kanban' );
    if ( ! kb || kb.hidden ) return;
    const lanes = {
      new: { title: 'Nuevos', ids: [10,20] },
      ack: { title: 'Reconocidos', ids: [30,40] },
      assigned: { title: 'Asignados', ids: [50] },
      resolved: { title: 'Resueltos', ids: [80] },
    };
    let html = '';
    for ( const k in lanes ) {
      const l = lanes[k];
      const items = rows.filter( r => l.ids.includes( r.status_id ) );
      html += '<div class="lane"><h3>' + l.title + ' (' + items.length + ')</h3>';
      html += items.map( r => {
        const sla = r.seconds_left !== null && r.seconds_left !== undefined
          ? ( r.seconds_left <= 0 ? 'sla-overdue' : ( r.seconds_left < 1800 ? 'sla-warn' : '' ) )
          : '';
        return '<div class="card '+sla+'" data-issue-id="'+r.id+'">'
          + '<span class="id">#'+r.id+'</span> '+esc(r.summary)+'<br>'
          + '<small>'+esc(r.os)+' · '+esc(r.handler || 'sin asignar')+'</small></div>';
      }).join('');
      html += '</div>';
    }
    kb.innerHTML = html;
  }

  function rowHtml( r ) {
    const prio = ( ['immediate','urgent'].includes(r.priority) ) ? 'red'
               : r.priority === 'high' ? 'orange'
               : r.priority === 'normal' ? 'blue' : 'gray';
    let slaClass = '', slaText = '—';
    if ( r.seconds_left !== null && r.seconds_left !== undefined ) {
      if ( r.seconds_left <= 0 ) {
        slaClass = 'sla-overdue';
        slaText = '⚠ Vencido hace ' + human( Math.abs( r.seconds_left ) );
      } else {
        slaText = 'En ' + human( r.seconds_left );
        if ( r.seconds_left < 1800 ) slaClass = 'sla-warn';
      }
    }
    const score = r.host_score;
    const sc = score === null ? 'gray' : score >= 80 ? 'green' : score >= 50 ? 'yellow' : 'red';
    return `<tr data-issue-id="${r.id}" data-email="${esc(r.reporter_email)}" data-anydesk="${esc(r.anydesk)}" data-os="${esc(r.os)}">
      <td><a href="#" class="rc-tech-row-open">#${r.id}</a></td>
      <td><span class="rc-tech-prio rc-tech-prio-${prio}">${esc(r.priority)}</span></td>
      <td><strong>${esc(r.summary)}</strong><br><small>${esc(r.category)}</small></td>
      <td>${esc(r.reporter)}<br><small>${esc(r.reporter_email)}</small></td>
      <td><span class="rc-tech-os rc-tech-os-${esc(r.os)}">${esc(r.os || '—')}</span></td>
      <td>${r.anydesk ? '<code>'+esc(r.anydesk)+'</code>' : '—'}</td>
      <td class="${slaClass}">${slaText}</td>
      <td>${score !== null ? '<span class="rc-tech-score rc-tech-score-'+sc+'">'+score+'</span>' : '—'}</td>
      <td class="rc-tech-actions">
        <button class="button button-small rc-tech-act" data-act="assign_me">Asignarme</button>
        <button class="button button-small rc-tech-act" data-act="diag">Diag</button>
        <button class="button button-small rc-tech-act" data-act="pdf">PDF</button>
        <button class="button button-small button-primary rc-tech-act" data-act="resolve">Resolver</button>
      </td>
    </tr>`;
  }

  function esc( s ) {
    return String( s ?? '' ).replace( /[&<>"']/g, c => ({
      '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
    })[c] );
  }

  function human( s ) {
    if ( s < 60 ) return s + 's';
    if ( s < 3600 ) return Math.floor( s / 60 ) + 'm';
    if ( s < 86400 ) return Math.floor( s / 3600 ) + 'h';
    return Math.floor( s / 86400 ) + 'd';
  }

  function doAction( act, tr ) {
    const issueId = tr.dataset.issueId;
    const email   = tr.dataset.email;
    const anydesk = tr.dataset.anydesk;
    const os      = tr.dataset.os;

    if ( act === 'assign_me' ) {
      api( 'action/assign_me', {
        method: 'POST',
        body: JSON.stringify( { issue_id: issueId } )
      } ).then( () => {
        tr.classList.add( 'rc-tech-row-flash-ok' );
        toast( i18n.assigned );
        setTimeout( refresh, 800 );
      } ).catch( e => toast( i18n.error + ': ' + (e.message || ''), true ) );
    }
    else if ( act === 'diag' ) {
      const scriptUrl = location.origin + '/scripts/' + (os || 'common') + '/diagnostico';
      if ( navigator.clipboard ) navigator.clipboard.writeText( scriptUrl );
      if ( anydesk ) window.location = 'anydesk:' + anydesk;
      api( 'action/diag_note', {
        method: 'POST',
        body: JSON.stringify( { issue_id: issueId, note: 'Inicio diagnóstico vía panel (script: '+scriptUrl+')' } )
      } ).then( () => toast( i18n.copyScript ) )
        .catch( e => toast( i18n.error + ': ' + (e.message || ''), true ) );
    }
    else if ( act === 'pdf' ) {
      if ( ! email ) { toast( 'Sin email cliente', true ); return; }
      toast( 'Generando PDF…' );
      api( 'action/pdf', {
        method: 'POST',
        body: JSON.stringify( { issue_id: issueId, email: email } )
      } ).then( () => toast( i18n.pdfAttached ) )
        .catch( e => toast( i18n.error + ': ' + (e.message || ''), true ) );
    }
    else if ( act === 'resolve' ) {
      const summary = prompt( 'Resumen para cliente (nota pública):', '' );
      if ( summary === null ) return;
      api( 'action/resolve', {
        method: 'POST',
        body: JSON.stringify( { issue_id: issueId, summary: summary } )
      } ).then( () => {
        tr.classList.add( 'rc-tech-row-flash-fade' );
        toast( i18n.resolved );
        setTimeout( refresh, 700 );
      } ).catch( e => toast( i18n.error + ': ' + (e.message || ''), true ) );
    }
  }

  function openSidebar( tr ) {
    const issueId = tr.dataset.issueId;
    const email   = tr.dataset.email;
    const sb = document.getElementById( 'rc-tech-sidebar' );
    sb.hidden = false;
    document.getElementById( 'rc-tech-sidebar-title' ).textContent = 'Ticket #' + issueId;
    const tl = document.getElementById( 'rc-tech-tab-timeline' );
    tl.innerHTML = '<em>Cargando…</em>';
    api( 'timeline/' + issueId + '?email=' + encodeURIComponent( email ) ).then( data => {
      const events = data.events || [];
      if ( ! events.length ) { tl.innerHTML = '<em>Sin eventos.</em>'; return; }
      tl.innerHTML = events.map( e => `
        <div class="rc-tech-timeline-event ${esc(e.source)}">
          <div class="ts">${esc(e.ts)}</div>
          <div>${esc(e.text)}</div>
          ${e.actor ? '<div class="actor">'+esc(e.actor)+'</div>' : ''}
          ${e.detail ? '<pre>'+esc(e.detail)+'</pre>' : ''}
        </div>
      `).join( '' );
    } ).catch( e => { tl.innerHTML = '<em>Error: '+esc(e.message || '')+'</em>'; } );
  }

  // ── Event delegation ──
  document.addEventListener( 'click', e => {
    if ( e.target.matches( '.rc-tech-act' ) ) {
      const tr = e.target.closest( 'tr' );
      doAction( e.target.dataset.act, tr );
    }
    else if ( e.target.matches( '.rc-tech-row-open' ) ) {
      e.preventDefault();
      openSidebar( e.target.closest( 'tr' ) );
    }
    else if ( e.target.matches( '.rc-tech-sidebar-close' ) ) {
      document.getElementById( 'rc-tech-sidebar' ).hidden = true;
    }
    else if ( e.target.matches( '.rc-tech-tabs button' ) ) {
      const tab = e.target.dataset.tab;
      document.querySelectorAll( '.rc-tech-tabs button' ).forEach( b => b.classList.toggle( 'active', b === e.target ) );
      document.querySelectorAll( '.rc-tech-tab-content' ).forEach( c => c.hidden = ( c.id !== 'rc-tech-tab-' + tab ) );
    }
    else if ( e.target.id === 'rc-tech-refresh' ) {
      refresh();
    }
    else if ( e.target.classList.contains( 'rc-tech-view-btn' ) ) {
      switchView( e.target.dataset.view );
    }
  } );

  // ── Cambio de vista: Cola (tabla) / Kanban / MantisBT (iframe) ──────────────
  function switchView( view ) {
    document.querySelectorAll( '.rc-tech-view-btn' ).forEach(
      b => b.classList.toggle( 'active', b.dataset.view === view )
    );
    const tableWrap = document.querySelector( '.rc-tech-table-wrap' );
    const kanban    = document.getElementById( 'rc-tech-kanban' );
    const mantis    = document.getElementById( 'rc-tech-mantis' );
    if ( tableWrap ) tableWrap.hidden = ( view !== 'table' );
    if ( kanban )    kanban.hidden    = ( view !== 'kanban' );
    if ( mantis )    mantis.hidden    = ( view !== 'mantis' );

    if ( view === 'mantis' ) {
      loadMantis();
    } else {
      refresh(); // tabla/kanban se repueblan; el iframe Mantis no necesita polling.
    }
  }

  // Carga diferida del iframe Mantis. Si no dispara 'load' en 5s → fallback.
  let mantisLoaded = false;
  function loadMantis() {
    const frame = document.getElementById( 'rc-tech-mantis-frame' );
    if ( ! frame || mantisLoaded ) return;
    mantisLoaded = true;
    const fallback = document.getElementById( 'rc-tech-mantis-fallback' );
    const timer = setTimeout( () => { if ( fallback ) fallback.hidden = false; }, 5000 );
    frame.addEventListener( 'load', () => {
      // Si cargó (no quedó en about:blank) ocultamos el fallback.
      if ( frame.src !== 'about:blank' ) {
        clearTimeout( timer );
        if ( fallback ) fallback.hidden = true;
      }
    } );
    frame.src = frame.dataset.src;
  }

  document.addEventListener( 'change', e => {
    if ( e.target.matches( '#rc-tech-os, #rc-tech-only-mine, #rc-tech-only-unassigned' ) ) refresh();
  } );
  document.addEventListener( 'input', e => {
    if ( e.target.id === 'rc-tech-q' ) {
      clearTimeout( window._rcTechQ );
      window._rcTechQ = setTimeout( refresh, 400 );
    }
  } );

  pollTimer = setInterval( refresh, pollInterval );
})();
