//
//  ReportView.swift
//  SafalCalendar
//
//  Created by Apple on 02/07/25.
//

import SwiftUI

struct ReportView: View {
    @State private var selectedModule: ReportModule = .IncidentReport

    var body: some View {
        List {
            ForEach(filteredModules, id: \.self) { module in
                NavigationLink(destination: destinationView(for: module)) {
                    HStack {
                        if module.rawValue == "Incident Report" {
                            Image("incident_icon")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.dynamicAccent)
                                .frame(width: 20, height: 20)
                               
                        }else if module.rawValue == "Dranage Report" {
                            Image("drainage_icon")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.dynamicAccent)
                                .frame(width: 20, height: 20)
                        }else if module.rawValue == "Vital Signs Report" {
                            Image("vital-signs")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.dynamicAccent)
                                .frame(width: 20, height: 20)
                        }else{
                            Image(systemName: module.icon)
                                .foregroundColor(.dynamicAccent)
                                .frame(width: 30)
                        }
                       

                        VStack(alignment: .leading) {
                            Text(module.rawValue)
                                .font(.headline)
                            
                                Text(module.subtitle)
                                .font(.caption)
                                .fontWeight(.light)
                                .foregroundColor(.secondary)
                            
                        }
                        Spacer()

                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            Task {
             //
            }
        }
        .listStyle(.plain)
        .navigationTitle("Reports")
    }
    
    /// Filtered modules based on user role
    private var filteredModules: [ReportModule] {
        let currentUser = TokenManager.shared.loadCurrentUser()
        
        // If user is not a Patient, show all modules
//        if currentUser?.role != "Patient" {
//            return ReportModule.allCases
//        } else {
//            // If user is a Patient, hide IncidentReport
//            return ReportModule.allCases.filter { $0 != .IncidentReport }
//        }
        return ReportModule.allCases
    }
    
    @ViewBuilder
    private func destinationView(for module: ReportModule) -> some View {
        switch module {
        case .changeLog:
            ReportsListView()
        case .IncidentReport:
            IncidentReportListView(reportType: "incident")
        case .DranageReport:
            IncidentReportListView(reportType: "drainage")
        case .VitalSignsReport:
            VitalSignsReportListView()
        }
    }
}

#Preview {
    ReportView()
}
