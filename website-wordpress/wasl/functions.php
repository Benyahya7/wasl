<?php
/**
 * Wasl theme functions.
 *
 * @package Wasl
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Enqueue fonts, the demo script and a small layer of theme CSS
 * (buttons, cards, tracking demo, FAQ) that theme.json doesn't cover.
 */
function wasl_enqueue_assets() {
	// Inter + Sora from Google Fonts (system-ui fallback if offline).
	wp_enqueue_style(
		'wasl-fonts',
		'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Sora:wght@600;700;800&display=swap',
		array(),
		null
	);

	wp_enqueue_style(
		'wasl-style',
		get_stylesheet_uri(),
		array(),
		wp_get_theme()->get( 'Version' )
	);

	wp_enqueue_style(
		'wasl-extra',
		get_theme_file_uri( 'assets/css/extra.css' ),
		array(),
		wp_get_theme()->get( 'Version' )
	);

	// Pickup-code demo on the front page (delivery #1044, code K7M2).
	wp_enqueue_script(
		'wasl-demo',
		get_theme_file_uri( 'assets/js/demo.js' ),
		array(),
		wp_get_theme()->get( 'Version' ),
		true
	);
}
add_action( 'wp_enqueue_scripts', 'wasl_enqueue_assets' );

/**
 * Theme setup: feed, title tag, post thumbnails, HTML5, editor styles.
 */
function wasl_setup() {
	add_theme_support( 'title-tag' );
	add_theme_support( 'post-thumbnails' );
	add_theme_support( 'automatic-feed-links' );
	add_theme_support(
		'html5',
		array( 'comment-list', 'comment-form', 'search-form', 'gallery', 'caption', 'style', 'script' )
	);
	add_theme_support( 'responsive-embeds' );
	add_editor_style( 'assets/css/extra.css' );
}
add_action( 'after_setup_theme', 'wasl_setup' );

/**
 * Pattern categories for the Wasl sections.
 */
function wasl_register_pattern_categories() {
	register_block_pattern_category(
		'wasl',
		array( 'label' => __( 'Wasl', 'wasl' ) )
	);
	register_block_pattern_category(
		'wasl-hero',
		array( 'label' => __( 'Wasl hero', 'wasl' ) )
	);
}
add_action( 'init', 'wasl_register_pattern_categories' );

/**
 * Front-page menu location (used by the header template part).
 */
function wasl_register_menus() {
	register_nav_menus(
		array(
			'primary' => __( 'Primary menu', 'wasl' ),
		)
	);
}
add_action( 'after_setup_theme', 'wasl_register_menus' );
