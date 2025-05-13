// import { Controller } from "@hotwired/stimulus";

// export default class extends Controller {
//   static targets = ["canvas"];

//   connect() {
//     console.log("✅ ChartsController connected!")

//     this.charts = [];

//     this.canvasTargets.forEach(canvas => {
//       const id = canvas.id;

//       let config = this.getChartConfig(id);
//       if (!config) return;

//       const chart = new Chart(canvas.getContext('2d'), config);
//       this.charts.push(chart);
//     });
//   }

//   disconnect() {
//     this.charts.forEach(chart => chart.destroy());
//   }

//   getChartConfig(id) {
//     const baseOptions = {
//       responsive: true,
//       maintainAspectRatio: false,
//       scales: {
//         y: {
//           beginAtZero: true,
//           grid: { color: 'rgba(255,255,255,0.08)' },
//           ticks: { color: '#b0b3c6' }
//         },
//         x: {
//           grid: { display: false },
//           ticks: { color: '#b0b3c6' }
//         }
//       }
//     };

//     switch (id) {
//       case "performanceChart":
//         return {
//           type: 'bar',
//           data: {
//             labels: ['12 Dec', '17 Dec', '25 Dec', '29 Dec', '4 Jan', '8 Jan', '15 Jan', '29 Jan', '6 Feb', '17 Feb', '24 Feb'],
//             datasets: [{
//               label: 'Points',
//               data: [40, 65, 75, 50, 35, 60, 45, 35, 40, 70, 50],
//               backgroundColor: ['#0dcaf0', '#0dcaf0', '#20c997', '#0dcaf0', '#0dcaf0', '#20c997', '#0dcaf0', '#0dcaf0', '#0dcaf0', '#20c997', '#0dcaf0'],
//               borderRadius: 8,
//               borderSkipped: false
//             }]
//           },
//           options: {
//             ...baseOptions,
//             plugins: { legend: { display: false } }
//           }
//         };

//       case "minutesChart":
//         return {
//           type: 'line',
//           data: {
//             labels: ['Match 1', 'Match 2', 'Match 3', 'Match 4', 'Match 5', 'Match 6'],
//             datasets: [{
//               label: 'Minutes',
//               data: [80, 65, 80, 75, 80, 70],
//               borderColor: '#0dcaf0',
//               backgroundColor: 'rgba(13, 202, 240, 0.1)',
//               tension: 0.4,
//               fill: true
//             }]
//           },
//           options: {
//             ...baseOptions,
//             plugins: { legend: { display: false } }
//           }
//         };

//       case "triesChart":
//         return {
//           type: 'bar',
//           data: {
//             labels: ['Match 1', 'Match 2', 'Match 3', 'Match 4', 'Match 5', 'Match 6'],
//             datasets: [{
//               label: 'Tries',
//               data: [1, 0, 2, 1, 0, 1],
//               backgroundColor: '#20c997',
//               borderRadius: 8
//             }]
//           },
//           options: {
//             ...baseOptions,
//             plugins: { legend: { display: false } }
//           }
//         };

//       case "pointsChart":
//         return {
//           type: 'line',
//           data: {
//             labels: ['Match 1', 'Match 2', 'Match 3', 'Match 4', 'Match 5', 'Match 6'],
//             datasets: [{
//               label: 'Points',
//               data: [5, 0, 10, 5, 0, 5],
//               borderColor: '#ffc107',
//               backgroundColor: 'rgba(255, 193, 7, 0.1)',
//               tension: 0.4,
//               fill: true
//             }]
//           },
//           options: {
//             ...baseOptions,
//             plugins: { legend: { display: false } }
//           }
//         };

//       case "cardsChart":
//         return {
//           type: 'bar',
//           data: {
//             labels: ['Match 1', 'Match 2', 'Match 3', 'Match 4', 'Match 5', 'Match 6'],
//             datasets: [
//               {
//                 label: 'Yellow Cards',
//                 data: [0, 1, 0, 0, 1, 0],
//                 backgroundColor: '#ffc107',
//                 borderRadius: 8
//               },
//               {
//                 label: 'Red Cards',
//                 data: [0, 0, 0, 0, 0, 0],
//                 backgroundColor: '#dc3545',
//                 borderRadius: 8
//               }
//             ]
//           },
//           options: {
//             ...baseOptions,
//             plugins: {
//               legend: {
//                 display: true,
//                 labels: { color: '#b0b3c6' }
//               }
//             }
//           }
//         };
//     }

//     return null;
//   }

// }
