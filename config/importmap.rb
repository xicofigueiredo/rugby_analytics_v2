# Pin npm packages by running ./bin/importmap

pin "application"
pin "turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "bootstrap/dist/js/bootstrap.bundle.min.js", to: "bootstrap.min.js", preload: true
pin "bootstrap/dist/css/bootstrap.min.css", to: "bootstrap.min.css", preload: true
pin "chart.js" # @4.4.9
pin "chartkick", to: "chartkick.js"
pin "Chart.bundle", to: "Chart.bundle.js"

pin_all_from "app/javascript/controllers", under: "controllers"
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
