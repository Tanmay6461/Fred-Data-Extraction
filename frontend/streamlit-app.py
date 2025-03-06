import streamlit as st
import pandas as pd
import requests
import json
import plotly.express as px

st.title('FRED - Economic Data')
st.subheader('10-Year Treasury Constant Maturity Minus 2-Year Treasury Constant Maturity')
if 'response' not in st.session_state:
    response = requests.get('https://culio1s6lj.execute-api.us-east-1.amazonaws.com/fred_stage/fred').json()
    st.session_state['response'] = response


if st.session_state['response']['statusCode']==200:
    data =st.session_state['response']['body']
    data2 = json.loads(data[0])
    data3 = json.loads(data[1])
    data4 = json.loads(data[2])
    
    df2 = pd.DataFrame(data2)
    df3 = pd.DataFrame(data3)
    df4 = pd.DataFrame(data4)
    # Ensure 'date' column is in datetime format
    # Sample DataFrame (Make sure your 'date' column is a DateTime type)
    df4['date'] = pd.to_datetime(df4['date'])

    # Create a complete date range
    full_date_range = pd.date_range(start=df4['date'].min(), end=df4['date'].max(), freq='D')

    # Reindex to include all dates
    df4 = df4.set_index('date').reindex(full_date_range).rename_axis('date').reset_index()

    # Forward-fill missing values
    df4['current_value'] = df4['current_value'].ffill()

    # Create the Plotly line chart
    fig = px.line(df4, x='date', y='current_value', 
                    title="Interactive Line Chart",
                    labels={'current_value': 'Value'},
                    hover_data={'date': False})

    # Display the Plotly chart in Streamlit
    st.plotly_chart(fig)
    st.header("Drill-Down Chart on Year and Month")
    # Dropdown for year selection
    selected_year = st.selectbox("Select Year", df2['year'].unique())
    # Filter dataframe based on the selected year
    filtered_df = df2[df2['year'] == selected_year]
    # Create a drill-down chart using Plotly
    fig = px.bar(filtered_df, x='month', y='average_value', title=f'Month-wise Data for {selected_year}')
    st.plotly_chart(fig)
    
    st.header('Year-wise Average Value')
    st.bar_chart(df3, x="year", y="average_value")
    # Sample data (you can replace this with your actual data)

    



