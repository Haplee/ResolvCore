<?php
/* Template Name: Aviso legal */
get_header();
$updated = '2026-05-20';
?>
<style>
.rc-legal { max-width: 820px; margin: 4rem auto; padding: 0 2rem; color: var(--rc-text); font-family: var(--rc-sans); }
.rc-legal h1 { font-family: var(--rc-mono); font-size: 2rem; font-weight: 700; margin-bottom: .5rem; }
.rc-legal .updated { font-family: var(--rc-mono); font-size: 12px; color: var(--rc-muted); margin-bottom: 2.5rem; letter-spacing: .04em; }
.rc-legal h2 { font-family: var(--rc-mono); font-size: 1.15rem; margin: 2rem 0 .75rem; color: var(--rc-accent); }
.rc-legal p, .rc-legal li { color: var(--rc-text); line-height: 1.75; margin-bottom: .75rem; }
.rc-legal ul { margin: 0 0 1rem 1.5rem; }
.rc-legal a { color: var(--rc-accent); }
.rc-legal .rc-legal-grid { display: grid; grid-template-columns: 180px 1fr; gap: .5rem 1.25rem; background: var(--rc-surface); border: 1px solid var(--rc-border); padding: 1.25rem; margin: 1rem 0; }
.rc-legal .rc-legal-grid dt { font-family: var(--rc-mono); font-size: 11px; color: var(--rc-muted); letter-spacing: .06em; align-self: center; }
.rc-legal .rc-legal-grid dd { font-size: 14px; margin: 0; }
</style>

<article class="rc-legal">
  <h1>Aviso legal</h1>
  <div class="updated">Última actualización: <?php echo esc_html( $updated ); ?></div>

  <p>En cumplimiento del artículo 10 de la Ley 34/2002, de 11 de julio, de Servicios de la Sociedad de la Información y de Comercio Electrónico (LSSI-CE), se ponen a disposición del usuario los siguientes datos identificativos del responsable del sitio web.</p>

  <h2>1. Datos del titular</h2>
  <dl class="rc-legal-grid">
    <dt>Titular</dt>      <dd>Francisco Vidal Mateo</dd>
    <dt>Actividad</dt>    <dd>Proyecto académico TFG ASIR — soporte técnico remoto (no actividad comercial)</dd>
    <dt>Sitio web</dt>    <dd><a href="https://resolvecore.website">resolvecore.website</a></dd>
    <dt>Contacto</dt>     <dd><a href="mailto:fvidalmateo@gmail.com">fvidalmateo@gmail.com</a></dd>
    <dt>Repositorio</dt>  <dd><a href="https://github.com/Haplee/ResolveCore" target="_blank" rel="noopener noreferrer">github.com/Haplee/ResolveCore</a></dd>
    <dt>Licencia</dt>     <dd>Código fuente bajo GPL-3.0-or-later</dd>
  </dl>

  <h2>2. Objeto</h2>
  <p>Este sitio web tiene finalidad informativa y demostrativa del Trabajo de Fin de Grado (TFG) del ciclo formativo de Administración de Sistemas Informáticos en Red (ASIR). No se ofrecen actualmente servicios comerciales remunerados; los formularios de contacto se utilizan únicamente para validar el flujo técnico del proyecto.</p>

  <h2>3. Condiciones de uso</h2>
  <p>El acceso al sitio implica la aceptación de las presentes condiciones. El usuario se compromete a:</p>
  <ul>
    <li>Utilizar los contenidos de forma lícita y conforme a la normativa vigente.</li>
    <li>No realizar acciones que puedan dañar la integridad del sitio o de terceros.</li>
    <li>No utilizar los formularios para envío masivo de mensajes (spam) o contenido fraudulento.</li>
  </ul>

  <h2>4. Propiedad intelectual e industrial</h2>
  <p>El código fuente del software publicado en este sitio está disponible bajo licencia <strong>GPL-3.0-or-later</strong> en el repositorio público. Los logos, marca «ResolveCore» y elementos gráficos son obra del titular. Otras marcas mencionadas (WordPress, MantisBT, AnyDesk, etc.) pertenecen a sus respectivos propietarios.</p>

  <h2>5. Limitación de responsabilidad</h2>
  <p>El titular no se hace responsable de los daños directos o indirectos derivados del uso del software publicado, que se ofrece «tal cual», sin garantía expresa ni implícita, en los términos descritos en la licencia GPL-3.0.</p>

  <h2>6. Legislación aplicable</h2>
  <p>Las presentes condiciones se rigen por la legislación española. Para cualquier controversia, las partes se someten a los Juzgados y Tribunales del domicilio del titular, salvo que la legislación aplicable disponga otra cosa.</p>

  <p style="margin-top:2rem;font-size:13px;color:var(--rc-muted)">Documento generado automáticamente como plantilla de cumplimiento básico LSSI-CE. Para un uso comercial real, consulta a un asesor legal.</p>
</article>

<?php get_footer(); ?>
