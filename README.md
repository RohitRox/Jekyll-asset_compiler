Jekyll-asset_compiler
=====================

Jekyll-asset_compiler is a Jekyll Plugin for asset compilation

## Usage
Put this plugin in _plugin folder
Define your bundle files  put it _bundle folder
```
  jekyll-site
  |
  | _plugin | asset_compiler.rb
  | _bundle | bundle_home.js
            | bundle_stylesheet.css
  | css | common.css
        | styles.css
  | js  | base.js
  
```
Make sure you have bundle initial.
Next, Add required files as

Inside bundle_home.js

```
http://ajax.googleapis.com/ajax/libs/jquery/1.8.1/jquery.min.js
/js/base.js
```
Inside bundle_stylesheet.css

```
/css/common.css
/css/styles.css
```
To include required bundle in your file just add

```
  {% asset %}home.js, stylesheet.css{% endasset %}
```
Not that you will only have to specify like home.js for bundle_home.js and likewise.
Compiled files will be generated at bundles directory inside _site and link will be automatically added.

## Dependencies
Uses the yui-compressor, make sure you have yui-compressor gem successfully installed