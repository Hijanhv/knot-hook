"use client";

import { useEffect, useRef } from "react";
import * as THREE from "three";

/**
 * The mark, rendered as the object it depicts.
 *
 * TorusKnotGeometry(p: 2, q: 3) is the trefoil, which is the same curve the 2D logo traces and
 * the simplest knot that cannot be untied. Using it here is not decoration: a project arguing
 * that several pools are tied into one price boundary can show the tie itself.
 *
 * Lit like a product shot rather than a demo scene. One key light, one rim, a large soft fill,
 * and a matte near-black surface on white. No colour anywhere, so it sits inside the monochrome
 * system instead of fighting it.
 *
 * Cost control, in order of how much they matter:
 *   - the loop is stopped whenever the canvas is off screen or the tab is hidden
 *   - device pixel ratio is capped at 2, which is invisible on a phone and halves the fill rate
 *   - geometry, material and renderer are disposed on unmount
 *   - prefers-reduced-motion renders one static frame and never starts the loop
 */
export default function KnotThree({ className = "" }: { className?: string }) {
  const host = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = host.current;
    if (!el) return;

    // Guard against browsers and CI environments with no WebGL at all. The section still reads
    // without the canvas, so failing quietly is better than throwing.
    let renderer: THREE.WebGLRenderer;
    try {
      renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "high-performance" });
    } catch {
      return;
    }

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100);
    camera.position.set(0, 0, 17.2);

    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(el.clientWidth, el.clientHeight, false);
    renderer.setClearAlpha(0);
    renderer.shadowMap.enabled = false;
    el.appendChild(renderer.domElement);
    renderer.domElement.style.width = "100%";
    renderer.domElement.style.height = "100%";
    renderer.domElement.style.display = "block";

    // ── the knot ──
    // 260 tubular segments keeps the silhouette clean where the strand crosses itself; below
    // about 180 the overlap shows facets on a large screen.
    const geometry = new THREE.TorusKnotGeometry(3.1, 0.92, 260, 32, 2, 3);
    const material = new THREE.MeshStandardMaterial({
      color: 0x0a0a0b,
      roughness: 0.34,
      metalness: 0.16,
    });
    const knot = new THREE.Mesh(geometry, material);
    scene.add(knot);

    // A single hairline of the same curve, drawn slightly proud of the surface. It catches the
    // eye as a drawn line rather than a lit solid, which ties the 3D object back to the flat
    // logo in the nav.
    const wire = new THREE.Mesh(
      new THREE.TorusKnotGeometry(3.1, 0.945, 220, 12, 2, 3),
      new THREE.MeshBasicMaterial({ color: 0x0a0a0b, wireframe: true, transparent: true, opacity: 0.055 })
    );
    scene.add(wire);

    // ── light ──
    scene.add(new THREE.HemisphereLight(0xffffff, 0xbcbcc4, 1.5));
    const key = new THREE.DirectionalLight(0xffffff, 2.6);
    key.position.set(-6, 8, 9);
    scene.add(key);
    const rim = new THREE.DirectionalLight(0xffffff, 3.2);
    rim.position.set(7, -4, -6);
    scene.add(rim);
    const fill = new THREE.DirectionalLight(0xffffff, 0.9);
    fill.position.set(9, 3, 4);
    scene.add(fill);

    // ── input ──
    // Pointer nudges the knot a few degrees and eases back. Scroll adds a slow turn, so the
    // object tracks the page rather than spinning independently of it.
    const pointer = { x: 0, y: 0 };
    const eased = { x: 0, y: 0 };
    let scrollTurn = 0;

    const onPointer = (ev: PointerEvent) => {
      const r = el.getBoundingClientRect();
      pointer.x = ((ev.clientX - r.left) / r.width - 0.5) * 2;
      pointer.y = ((ev.clientY - r.top) / r.height - 0.5) * 2;
    };
    const onScroll = () => {
      scrollTurn = window.scrollY * 0.0016;
    };
    window.addEventListener("pointermove", onPointer, { passive: true });
    window.addEventListener("scroll", onScroll, { passive: true });

    const resize = () => {
      const w = el.clientWidth;
      const h = el.clientHeight;
      if (!w || !h) return;
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
      renderer.setSize(w, h, false);
    };
    const ro = new ResizeObserver(resize);
    ro.observe(el);
    resize();

    // ── loop ──
    let raf = 0;
    let visible = true;
    const clock = new THREE.Clock();

    const frame = () => {
      raf = requestAnimationFrame(frame);
      const t = clock.getElapsedTime();

      eased.x += (pointer.x - eased.x) * 0.045;
      eased.y += (pointer.y - eased.y) * 0.045;

      knot.rotation.x = t * 0.13 + scrollTurn + eased.y * 0.28;
      knot.rotation.y = t * 0.19 + scrollTurn * 1.4 + eased.x * 0.36;
      knot.position.y = Math.sin(t * 0.55) * 0.12;
      wire.rotation.copy(knot.rotation);
      wire.position.copy(knot.position);

      renderer.render(scene, camera);
    };

    const start = () => {
      if (!raf && visible && !document.hidden) {
        clock.start();
        raf = requestAnimationFrame(frame);
      }
    };
    const stop = () => {
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
    };

    const io = new IntersectionObserver(([e]) => {
      visible = e.isIntersecting;
      if (visible) start();
      else stop();
    });
    io.observe(el);

    const onVisibility = () => (document.hidden ? stop() : start());
    document.addEventListener("visibilitychange", onVisibility);

    if (reduced) {
      knot.rotation.set(0.5, 0.9, 0);
      wire.rotation.copy(knot.rotation);
      renderer.render(scene, camera);
    } else {
      start();
    }

    return () => {
      stop();
      io.disconnect();
      ro.disconnect();
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("pointermove", onPointer);
      window.removeEventListener("scroll", onScroll);
      geometry.dispose();
      material.dispose();
      wire.geometry.dispose();
      (wire.material as THREE.Material).dispose();
      renderer.dispose();
      el.removeChild(renderer.domElement);
    };
  }, []);

  return <div ref={host} aria-hidden className={className} />;
}
